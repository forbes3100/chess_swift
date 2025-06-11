#!/usr/bin/env bash
set -euo pipefail
apt-get update
apt-get install -y wget clang libicu-dev libcurl4-openssl-dev
wget -q https://download.swift.org/swift-5.9-release/ubuntu22.04/swift-5.9-RELEASE/swift-5.9-RELEASE-ubuntu22.04.tar.gz
tar -xzf swift-5.9-RELEASE-ubuntu22.04.tar.gz -C /usr/local --strip-components=1
