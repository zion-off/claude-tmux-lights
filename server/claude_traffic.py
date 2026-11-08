#!/usr/bin/env python3
"""Publishes the status of every live Claude Code session in tmux.

`serve` reads the session files in ~/.claude/sessions, mirrors each status onto its
tmux window (@claude_status / @claude_color), and streams one JSON line to every
client connected to the port whenever the picture changes. `snapshot` prints the
current picture once. `stream` prints the same lines to stdout and changes nothing
in tmux, so a client can run it over ssh (`ssh host python3 - stream < this_file`).

Each line is {"v": 1, "claudes": [...]}. An entry has `id` (stable for the window's
lifetime), `group` (the tmux session), `label` (the text to show) and `status`.
`session` and `window` repeat group and label for clients that predate v1.
"""
import argparse
import asyncio
import json
import logging
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set

PROTOCOL_VERSION = 1
SESSIONS_DIR = Path.home() / ".claude" / "sessions"
DEFAULT_PORT = 47500
DEFAULT_INTERVAL_SECONDS = 1.0
HEARTBEAT_SECONDS = 15.0
CLIENT_WRITE_TIMEOUT_SECONDS = 2.0

# "shell" means Claude has stopped and only a background shell command is still running.
STATUS_RANK = {"idle": 1, "shell": 2, "busy": 3, "waiting": 4}
STATUS_COLORS = {"waiting": "#ffb000", "busy": "#4a90e2", "shell": "#2f5f99", "idle": "#808080"}
UNKNOWN_STATUS_COLOR = "#c6c6c6"

logger = logging.getLogger("claude_traffic")


@dataclass(frozen=True)
class ClaudeSession:
    pid: int
    status: str
    tmux_session: str
    window_id: str


@dataclass(frozen=True)
class TmuxWindow:
    session: str
    window_id: str
    index: int
    claude_status: str


def process_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


class SessionReader:
    def __init__(self, directory: Path):
        self._directory = directory

    def read_live(self) -> List[ClaudeSession]:
        sessions = []
        for path in sorted(self._directory.glob("*.json")):
            session = self._parse(path)
            if session is not None and process_alive(session.pid):
                sessions.append(session)
        return sessions

    @staticmethod
    def _parse(path: Path) -> Optional[ClaudeSession]:
        try:
            data = json.loads(path.read_text())
            tmux_ref = data.get("tmux") or ""
            tmux_session, _, pane_ref = tmux_ref.partition(":")
            if not tmux_session or not pane_ref:
                return None
            return ClaudeSession(
                pid=int(data["pid"]),
                status=str(data["status"]),
                tmux_session=tmux_session,
                window_id=pane_ref.split(".")[0],
            )
        except (OSError, ValueError, KeyError):
            logger.debug("skipped unreadable session file=%s", path.name)
            return None


class TmuxClient:
    _FIELD_SEPARATOR = "|"

    def list_windows(self) -> List[TmuxWindow]:
        fmt = self._FIELD_SEPARATOR.join(
            ["#{session_name}", "#{window_id}", "#{window_index}", "#{@claude_status}"]
        )
        output = self._run(["list-windows", "-a", "-F", fmt])
        windows = []
        for line in output.splitlines():
            session, window_id, index, status = line.split(self._FIELD_SEPARATOR, 3)
            windows.append(TmuxWindow(session, window_id, int(index), status))
        return windows

    def mark_window(self, window_id: str, status: str) -> None:
        color = STATUS_COLORS.get(status, UNKNOWN_STATUS_COLOR)
        self._run([
            "set-option", "-w", "-t", window_id, "@claude_status", status, ";",
            "set-option", "-w", "-t", window_id, "@claude_color", color,
        ])

    def clear_window(self, window_id: str) -> None:
        self._run([
            "set-option", "-wu", "-t", window_id, "@claude_status", ";",
            "set-option", "-wu", "-t", window_id, "@claude_color",
        ])

    def refresh_status_line(self) -> None:
        subprocess.run(["tmux", "refresh-client", "-S"], capture_output=True, check=False)

    @staticmethod
    def _run(args: List[str]) -> str:
        result = subprocess.run(["tmux"] + args, capture_output=True, text=True, check=True)
        return result.stdout


def strongest_session_per_window(sessions: List[ClaudeSession]) -> Dict[str, ClaudeSession]:
    strongest: Dict[str, ClaudeSession] = {}
    for session in sessions:
        current = strongest.get(session.window_id)
        if current is None or STATUS_RANK.get(session.status, 0) > STATUS_RANK.get(current.status, 0):
            strongest[session.window_id] = session
    return strongest


def build_snapshot(windows: List[TmuxWindow], desired: Dict[str, ClaudeSession]) -> str:
    claudes = [
        {
            "id": window.window_id,
            "group": window.session,
            "label": str(window.index),
            "session": window.session,
            "window": window.index,
            "status": desired[window.window_id].status,
        }
        for window in windows
        if window.window_id in desired
    ]
    claudes.sort(key=lambda claude: (claude["session"], claude["window"]))
    return json.dumps({"v": PROTOCOL_VERSION, "claudes": claudes}, sort_keys=True)


class Broadcaster:
    def __init__(self):
        self._writers: Set[asyncio.StreamWriter] = set()
        self.latest = ""

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        peer = writer.get_extra_info("peername")
        logger.info("client connected peer=%s clients=%d", peer, len(self._writers) + 1)
        self._writers.add(writer)
        try:
            if self.latest:
                await self._send(writer, self.latest)
            await reader.read()
        except (ConnectionError, asyncio.TimeoutError):
            pass
        finally:
            self._drop(writer)
            logger.info("client disconnected peer=%s clients=%d", peer, len(self._writers))

    async def publish(self, line: str) -> None:
        self.latest = line
        for writer in list(self._writers):
            try:
                await self._send(writer, line)
            except (ConnectionError, asyncio.TimeoutError):
                logger.warning("dropping stalled client")
                self._drop(writer)

    @staticmethod
    async def _send(writer: asyncio.StreamWriter, line: str) -> None:
        writer.write((line + "\n").encode())
        await asyncio.wait_for(writer.drain(), CLIENT_WRITE_TIMEOUT_SECONDS)

    def _drop(self, writer: asyncio.StreamWriter) -> None:
        self._writers.discard(writer)
        writer.close()


class StatusService:
    def __init__(self, reader: SessionReader, tmux: TmuxClient, broadcaster: Broadcaster):
        self._reader = reader
        self._tmux = tmux
        self._broadcaster = broadcaster
        self._warned_statuses: Set[str] = set()

    def current_snapshot(self) -> str:
        windows = self._tmux.list_windows()
        return build_snapshot(windows, self._desired_sessions())

    async def run(self, interval: float) -> None:
        while True:
            try:
                await self._tick()
            except subprocess.CalledProcessError as error:
                logger.error("tmux failed args=%s stderr=%s", error.cmd[1:4], error.stderr.strip())
            await asyncio.sleep(interval)

    async def _tick(self) -> None:
        windows = self._tmux.list_windows()
        desired = self._desired_sessions()
        changed = self._sync_tmux(windows, desired)
        snapshot = build_snapshot(windows, desired)
        if snapshot != self._broadcaster.latest:
            logger.info("snapshot changed %s", snapshot)
            await self._broadcaster.publish(snapshot)
        if changed:
            self._tmux.refresh_status_line()

    def _desired_sessions(self) -> Dict[str, ClaudeSession]:
        sessions = self._reader.read_live()
        for session in sessions:
            if session.status not in STATUS_RANK and session.status not in self._warned_statuses:
                self._warned_statuses.add(session.status)
                logger.warning("unknown status=%s pid=%d", session.status, session.pid)
        return strongest_session_per_window(sessions)

    def _sync_tmux(self, windows: List[TmuxWindow], desired: Dict[str, ClaudeSession]) -> bool:
        changed = False
        for window in windows:
            session = desired.get(window.window_id)
            wanted = session.status if session else ""
            if wanted == window.claude_status:
                continue
            if wanted:
                self._tmux.mark_window(window.window_id, wanted)
            else:
                self._tmux.clear_window(window.window_id)
            logger.info(
                "window=%s:%d status=%s (was %s)",
                window.session, window.index, wanted or "none", window.claude_status or "none",
            )
            changed = True
        return changed


async def serve(port: int, interval: float) -> int:
    broadcaster = Broadcaster()
    service = StatusService(SessionReader(SESSIONS_DIR), TmuxClient(), broadcaster)
    try:
        server = await asyncio.start_server(broadcaster.handle_client, "127.0.0.1", port)
    except OSError as error:
        logger.error("cannot listen on port=%d: %s", port, error)
        return 1
    logger.info("serving on 127.0.0.1:%d interval=%.1fs", port, interval)
    async with server:
        await service.run(interval)
    return 0


def stream(interval: float) -> int:
    service = StatusService(SessionReader(SESSIONS_DIR), TmuxClient(), Broadcaster())
    last_line, last_sent = "", 0.0
    while True:
        try:
            line = service.current_snapshot()
        except subprocess.CalledProcessError:
            line = build_snapshot([], {})
        except FileNotFoundError:
            print("tmux is not installed", file=sys.stderr)
            return 1
        now = time.monotonic()
        if line != last_line or now - last_sent >= HEARTBEAT_SECONDS:
            try:
                print(line, flush=True)
            except OSError:
                os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
                return 0
            last_line, last_sent = line, now
        time.sleep(interval)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    serve_parser = sub.add_parser("serve")
    serve_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    serve_parser.add_argument("--interval", type=float, default=DEFAULT_INTERVAL_SECONDS)
    stream_parser = sub.add_parser("stream")
    stream_parser.add_argument("--interval", type=float, default=DEFAULT_INTERVAL_SECONDS)
    sub.add_parser("snapshot")
    args = parser.parse_args()

    if args.command == "snapshot":
        service = StatusService(SessionReader(SESSIONS_DIR), TmuxClient(), Broadcaster())
        print(service.current_snapshot())
        return 0

    if args.command == "stream":
        return stream(args.interval)

    logging.basicConfig(
        filename=Path(__file__).resolve().parent / "claude-traffic.log", level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S",
    )
    return asyncio.run(serve(args.port, args.interval))


if __name__ == "__main__":
    sys.exit(main())
