# SDDC-Core: Software Defined Data Center Framework

Building a production-grade, governed infrastructure on an Intel Mini cluster using GitOps, Home Automation, and AI-driven documentation.

## 🚀 Overview
SDDC-Core is the central repository for the "Elemental Stones" architecture. It automates the lifecycle of infrastructure decisions (ADRs) and configuration management. By bridging GitHub, n8n, and Confluence, this project ensures that the live environment and its documentation are always in sync.

## 🪨 The Elemental Stones Framework
We utilize a tiered logical storage hierarchy to optimize performance and data durability:

* **Earth (IOPS Intensive):** High-speed storage for Postgres and Perforce metadata.
* **Wind (High Frequency):** Optimized for volatile configurations and Docker Compose files.
* **Water (High Volume):** Scalable storage for large assets, media, and long-term logs.

## 🤖 GitOps Documentation Pipeline
This repository utilizes an **n8n-powered Agent** to manage architectural records:
1.  **MAC Filter (Move, Add, Change):** Automatically identifies added or modified files in the `/docs` folder.
2.  **State Machine:** Logic branches between `POST` (Creation) and `PUT` (Update) based on file status.
3.  **Human-in-the-Loop:** Automated Gmail approval gate to verify documentation accuracy before syncing to Confluence.
4.  **Traceability:** Automatic linking between GitHub commits, Jira Tasks, and Confluence Pages.

## 📁 Project Structure
```text
.
├── docs/               # ADRs and Architectural Documentation
├── config/             # Wind-tier service configurations
├── scripts/            # Automation and health monitoring
└── README.md           # Project Command Center

## Privacy Statement
---
[Privacy Policy](https://sonydogg.github.io/SDDC-Core/privacy)