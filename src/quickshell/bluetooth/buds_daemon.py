#!/usr/bin/env python3
"""Galaxy Buds status helper.

Usage: buds_daemon.py <MAC> [--dump]

Opens the Samsung SPP channel of a Galaxy Buds device and prints one JSON
object per line whenever the earbuds report their state:
  {"left": 78, "right": 81, "case": 45, "wearLeft": true, "wearRight": true, "noise": "anc"}

Commands are read from stdin, one per line:
  noise off | noise ambient | noise anc | noise adaptive

Exits when the connection drops; the caller restarts it.
"""

import json
import os
import select
import socket
import struct
import sys

SAMSUNG_SPP_UUID = "2e73a4ad-332d-41fc-90e2-16bef06523f2"
SDP_PSM = 1

SOM, EOM = 0xFD, 0xDD

MSG_STATUS_UPDATED = 0x60
MSG_EXTENDED_STATUS_UPDATED = 0x61
MSG_NOISE_CONTROLS = 0x78
MSG_NOISE_CONTROLS_UPDATE = 0x77

NOISE_BY_NAME = {"off": 0, "anc": 1, "ambient": 2, "adaptive": 3}
NOISE_BY_VALUE = {v: k for k, v in NOISE_BY_NAME.items()}


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def crc16(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


def encode(msg_id, payload=b""):
    body = bytes([msg_id]) + payload
    header = len(body) + 2
    crc = crc16(body)
    return bytes([SOM]) + struct.pack("<H", header) + body + struct.pack("<H", crc) + bytes([EOM])


def find_rfcomm_channel(mac, uuid):
    """Minimal SDP ServiceSearchAttributeRequest for one 128-bit UUID."""
    uuid_bytes = bytes.fromhex(uuid.replace("-", ""))
    pattern = bytes([0x35, 0x11, 0x1C]) + uuid_bytes
    attrs = bytes([0x35, 0x05, 0x0A, 0x00, 0x00, 0xFF, 0xFF])

    sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
    sock.settimeout(8)
    try:
        sock.connect((mac, SDP_PSM))
        data = b""
        cont = b"\x00"
        txn = 1
        while True:
            params = pattern + struct.pack(">H", 0xFFFF) + attrs + cont
            sock.send(struct.pack(">BHH", 0x06, txn, len(params)) + params)
            resp = sock.recv(4096)
            if not resp or resp[0] != 0x07:
                return None
            count = struct.unpack(">H", resp[5:7])[0]
            data += resp[7:7 + count]
            cont = resp[7 + count:]
            txn += 1
            if not cont or cont[0] == 0:
                break
    finally:
        sock.close()

    # ProtocolDescriptorList contains: UUID16 RFCOMM (0x19 0x00 0x03) followed by uint8 channel (0x08 ch)
    i = data.find(bytes([0x19, 0x00, 0x03, 0x08]))
    return data[i + 4] if i != -1 and i + 4 < len(data) else None


def wear(nibble):
    # 1 = worn, 2 = idle (out of ear), 3 = in case, 0 = disconnected
    return nibble == 1


def parse(msg_id, p, state):
    if msg_id == MSG_EXTENDED_STATUS_UPDATED and len(p) >= 8:
        # revision, earType, battL, battR, coupled, mainConnection, placement, battCase,
        # soundSync, equalizer, touchLock, touchOptions, noiseControls, ...
        state["left"], state["right"] = p[2], p[3]
        state["wearLeft"], state["wearRight"] = wear(p[6] >> 4), wear(p[6] & 0x0F)
        state["case"] = p[7]
        if len(p) > 12 and p[12] in NOISE_BY_VALUE:
            state["noise"] = NOISE_BY_VALUE[p[12]]
        return True
    if msg_id == MSG_STATUS_UPDATED and len(p) >= 7:
        # revision, battL, battR, coupled, mainConnection, placement, battCase
        state["left"], state["right"] = p[1], p[2]
        state["wearLeft"], state["wearRight"] = wear(p[5] >> 4), wear(p[5] & 0x0F)
        state["case"] = p[6]
        return True
    if msg_id == MSG_NOISE_CONTROLS_UPDATE and len(p) >= 1 and p[0] in NOISE_BY_VALUE:
        state["noise"] = NOISE_BY_VALUE[p[0]]
        return True
    return False


def frames(buf):
    """Yield (msg_id, payload) from a byte buffer; returns leftover bytes."""
    out = []
    while True:
        start = buf.find(bytes([SOM]))
        if start == -1:
            return out, b""
        buf = buf[start:]
        if len(buf) < 3:
            return out, buf
        size = struct.unpack("<H", buf[1:3])[0] & 0x03FF
        total = 3 + size + 1
        if len(buf) < total:
            return out, buf
        frame, buf = buf[:total], buf[total:]
        if frame[-1] != EOM:
            buf = frame[1:] + buf
            continue
        body = frame[3:-3]
        if body:
            out.append((body[0], body[1:]))


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    mac = sys.argv[1].upper()
    dump = "--dump" in sys.argv

    try:
        channel = find_rfcomm_channel(mac, SAMSUNG_SPP_UUID)
    except OSError as e:
        emit({"error": "sdp", "detail": str(e)})
        return 1
    if channel is None:
        emit({"error": "unsupported"})
        return 1

    sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
    try:
        sock.settimeout(10)
        sock.connect((mac, channel))
        sock.settimeout(None)
    except OSError as e:
        emit({"error": "connect", "detail": str(e)})
        return 1

    state = {}
    buf = b""
    stdin_fd = sys.stdin.fileno()
    watch = [sock, stdin_fd]
    try:
        while True:
            ready, _, _ = select.select(watch, [], [])
            if sock in ready:
                chunk = sock.recv(2048)
                if not chunk:
                    break
                found, buf = frames(buf + chunk)
                changed = False
                for msg_id, payload in found:
                    if dump:
                        print(f"id=0x{msg_id:02x} len={len(payload)} {payload.hex(' ')}", file=sys.stderr, flush=True)
                    changed = parse(msg_id, payload, state) or changed
                if changed:
                    emit(state)
            if stdin_fd in ready:
                line = os.read(stdin_fd, 256).decode(errors="ignore")
                if not line:
                    watch.remove(stdin_fd)
                    continue
                for cmd in line.split("\n"):
                    parts = cmd.split()
                    if len(parts) == 2 and parts[0] == "noise" and parts[1] in NOISE_BY_NAME:
                        sock.send(encode(MSG_NOISE_CONTROLS, bytes([NOISE_BY_NAME[parts[1]]])))
                        state["noise"] = parts[1]
                        emit(state)
    except OSError:
        pass
    finally:
        sock.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
