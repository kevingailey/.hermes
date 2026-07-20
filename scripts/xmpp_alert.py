#!/usr/bin/env python3
"""Shared XMPP sender and alert helpers for monitoring scripts."""

import os
import sys
import asyncio
from datetime import datetime

import slixmpp


def send_xmpp(message):
    """Send a message via XMPP using env var credentials. Call from asyncio."""
    jid = os.environ.get("XMPP_JID")
    password = os.environ.get("XMPP_PASSWORD")
    recipient = os.environ.get("XMPP_RECIPIENT")

    if not all([jid, password, recipient]):
        print("Error: XMPP_JID, XMPP_PASSWORD, and XMPP_RECIPIENT env vars required.", file=sys.stderr)
        sys.exit(1)

    bot = _AlertBot(jid, password, recipient, message)
    host = os.environ.get("XMPP_HOST")
    port = int(os.environ.get("XMPP_PORT", "5222"))

    if host:
        connect_future = bot.connect(host, port)
    else:
        connect_future = bot.connect()

    yield bot, connect_future


class _AlertBot(slixmpp.ClientXMPP):
    def __init__(self, jid, password, recipient, message):
        slixmpp.ClientXMPP.__init__(self, jid, password)
        self.recipient = recipient
        self.message = message
        self.add_event_handler("session_start", self._start)
        self.add_event_handler("failed_auth", self._auth_failed)

    async def _start(self, event):
        self.send_presence()
        await self.get_roster()
        self.send_message(
            mto=self.recipient,
            mbody=self.message,
            mtype="chat",
        )
        await asyncio.sleep(2)
        self.disconnect()

    def _auth_failed(self, event):
        print(f"XMPP auth failed for {self.boundjid}", file=sys.stderr)
        self.disconnect()


def alert(title, body):
    """Format and send an alert via XMPP. Runs the full async cycle."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message = f"[DockerVPS] {title}\n{timestamp}\n{'='*40}\n{body}"
    print(message)

    asyncio.run(_send_async(message))


async def _send_async(message):
    jid = os.environ.get("XMPP_JID")
    password = os.environ.get("XMPP_PASSWORD")
    recipient = os.environ.get("XMPP_RECIPIENT")

    if not all([jid, password, recipient]):
        print("Error: XMPP_JID, XMPP_PASSWORD, and XMPP_RECIPIENT env vars required.", file=sys.stderr)
        sys.exit(1)

    bot = _AlertBot(jid, password, recipient, message)
    host = os.environ.get("XMPP_HOST")
    port = int(os.environ.get("XMPP_PORT", "5222"))

    if host:
        connect_future = bot.connect(host, port)
    else:
        connect_future = bot.connect()

    await connect_future
    while bot.is_connected():
        await asyncio.sleep(1)
