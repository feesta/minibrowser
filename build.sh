#!/bin/sh
# builds ./mini next to home.html and putty-ink.css (needs Xcode Command Line Tools)
cd "$(dirname "$0")" && swiftc -O mini.swift -o mini && echo "built ./mini"
