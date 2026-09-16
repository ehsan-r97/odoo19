#!/usr/bin/env bash
cd "$(dirname "$0")"
source venv/bin/activate
exec ./odoo-bin -c "$PWD/odoo.conf"
