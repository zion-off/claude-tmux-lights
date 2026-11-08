import json
import socket
import sys
import threading
import time

PORT = int(sys.argv[1])
STEP = float(sys.argv[2]) if len(sys.argv) > 2 else 4.0

lock = threading.Lock()
clients = []
state = []
srv = None


def entry(session, status, window):
    return {"session": session, "status": status, "window": window}


def frame():
    return (json.dumps({"claudes": state}) + "\n").encode()


def broadcast(raw):
    with lock:
        for c in list(clients):
            try:
                c.sendall(raw)
            except OSError:
                clients.remove(c)


def listen():
    global srv
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", PORT))
    srv.listen()


def accept_loop():
    while True:
        try:
            conn, _ = srv.accept()
        except OSError:
            time.sleep(0.1)
            continue
        with lock:
            clients.append(conn)
            conn.sendall(frame())


def set_state(new, label):
    global state
    state = new
    print(f"[{time.strftime('%H:%M:%S')}] {label}", flush=True)
    broadcast(frame())


def drop_all():
    global srv
    print(f"[{time.strftime('%H:%M:%S')}] stream drops, port closed", flush=True)
    srv.close()
    with lock:
        for c in clients:
            c.close()
        clients.clear()


listen()
threading.Thread(target=accept_loop, daemon=True).start()

state = [entry("work", "idle", 1), entry("work", "busy", 2), entry("work", "busy", 3)]
print(f"[{time.strftime('%H:%M:%S')}] start: 1 idle, 2 busy, 3 busy", flush=True)
time.sleep(STEP)

set_state([entry("work", "idle", 1), entry("work", "waiting", 2), entry("work", "busy", 3)], "window 2 waiting")
time.sleep(STEP)

broadcast(b"not json\n")
set_state([entry("work", "waiting", 2), entry("work", "busy", 3), entry("x", "frobnicating", 4)],
          "window 1 closed, window 4 has an unknown status")
time.sleep(STEP)

drop_all()
time.sleep(STEP * 1.5)

listen()
print(f"[{time.strftime('%H:%M:%S')}] port open again", flush=True)
time.sleep(STEP)

set_state([], "no Claudes")
time.sleep(STEP)

set_state([entry("work", "idle", 1), entry("work", "waiting", 2)], "two Claudes again")
while True:
    time.sleep(3600)
