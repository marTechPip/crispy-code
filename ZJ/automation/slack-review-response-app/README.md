# Slack App for Managing AI-Generated Responses

This repository contains the code for a Slack application that allows users to interact with AI-generated responses to Google reviews. The app is built using Slack's Bolt framework and integrates with Retool for receiving AI-generated responses and processing approved responses.

## Table of Contents
- [Project Overview](#project-overview)
- [Setup Instructions](#setup-instructions)
- [Running the App Locally](#running-the-app-locally)
- [Testing the Integration](#testing-the-integration)
- [Troubleshooting](#troubleshooting)

## Project Overview

This Slack app posts AI-generated responses to a dedicated channel where users can approve or edit the responses. Once approved, the response is sent to Retool for further processing and storage.

### Key Features:
- Posts AI-generated responses to Slack.
- Allows users to approve or edit responses.
- Sends approved responses to Retool via a webhook.

## Setup Instructions

### Prerequisites
- Node.js installed on your local machine.
- A Slack workspace and a Slack app created in the Slack API dashboard.
- Retool account with a webhook URL configured.

### Cloning the Repository

```bash
git clone https://github.com/zenjob/martech/tree/main/slack-review-response-app
cd slack-review-response-app
```

### Installing Dependencies

```bash
npm install
```

### Configuring Environment Variables

```plaintext
SLACK_BOT_TOKEN=slack-bot-token
SLACK_SIGNING_SECRET=slack-signing-secret
SLACK_APP_TOKEN=slack-app-token
RETOOL_API_KEY=retool-api-key
```

### Creating and Configuring Slack App

1. Create a new Slack App on the Slack API dashboard
2. Enable the necessary permissions and scopes:
    - chat:write
    - commands
    - im:history
    - im:write
3. Enable Socket Mode
4. Install the app to the workspace and copy the slack-bot-token and slack-signing-secret into the .env file

### Setting up Retool

1. Create a new Retool workflow
2. Add Webhook trigger and copy the Webhook URL
3. Paste URL as *retoolWebhookUrl* in the Slack app code

## Running the App Locally

```bash
node app.js
```

- Since Socket Mode is enabled there is no need to expose your local server

## Testing the Integration

### Testing with Postman

1. Copy the Webhook URL from the Slack API dashboard > Incoming Webhooks section
2. Request setup
    - Method: POST
    - URL: Paste the Webhook URL
    - Headers:
        - Content-Type: application/json
    - Body:
        - Copy and paste the *retool-payload.json* file
3. Verify that the a new message is posted in the Slack channel
4. Verify functionality of the buttons, etc.

## Troubleshooting

- Verify that the environment variables are defined properly