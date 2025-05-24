# ServiceTaskManager.ps1

A simple PowerShell GUI tool to identify and disable unnecessary Windows services and scheduled tasks that may affect privacy, performance, or system clarity.

## Features

- Lists commonly unwanted Windows services (e.g. telemetry, Xbox, Edge update)
- Detects and shows scheduled tasks related to feedback, tracking, or usage data
- Allows you to selectively disable them via checkboxes
- Simple and clean Windows Forms-based GUI

## How to Run

Run the following commands in PowerShell (Administrator Privileges Required):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
./ServiceTaskManager.ps1
