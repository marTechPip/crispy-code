const { App } = require('@slack/bolt');
require('dotenv').config();

const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  socketMode: true,
  appToken: process.env.SLACK_APP_TOKEN,
  customRoutes: [
    {
      path: '/liveness',
      method: 'get',
      handler: (req, res) => {
        res.writeHead(200);
        res.end('OK');
      }
    },
    {
      path: '/readiness',
      method: 'get',
      handler: (req, res) => {
        res.writeHead(200);
        res.end('OK');
      }
    }
  ]
});

// Function to get the current date and time in Germany's time zone (handles DST automatically)
function getGermanTime() {
  return new Date().toLocaleString("de-DE", { timeZone: "Europe/Berlin" });
}

// Initial Approve action triggers confirmation modal
app.action('click_approve', async ({ body, ack, client, logger }) => {
  await ack();

  const responseBlock = body.message.blocks.find(block => block.block_id === 'response_text');
  const response = responseBlock ? responseBlock.text.text : 'No response available';

  const reviewIDBlock = body.message.blocks.find(block => block.block_id === 'review_id');
  const reviewID = reviewIDBlock ? reviewIDBlock.text.text : 'No review ID available';

  const privateMetadata = JSON.stringify({
    ts: body.message.ts,
    channel: body.channel.id,
    reviewID,
    response
  });

  try {
    // Show confirmation modal with Approve and Cancel buttons
    await client.views.open({
      trigger_id: body.trigger_id,
      view: {
        "type": "modal",
        "callback_id": "confirm_approve_modal",
        "title": {
          "type": "plain_text",
          "text": "Confirm Approval",
          "emoji": true
        },
        "submit": {
          "type": "plain_text",
          "text": "Submit",
          "emoji": true
        },
        "close": {
          "type": "plain_text",
          "text": "Cancel",
          "emoji": true
        },
        "private_metadata": privateMetadata,
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": `Are you sure you want to approve this response?\n\n*Once submitted, this cannot be undone.*`
            }
          },
          {
            "type": "section",
            "text": {
              "type": "plain_text",
              "text": `Review ID: ${reviewID}`,
              "emoji": true
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": `*AI response:*\n${response}`
            }
          }
        ]
      }
    });

  } catch (error) {
    logger.error('Error opening confirmation modal', error);
  }
});

// Handling submission of the approved response
app.view('confirm_approve_modal', async ({ ack, view, body, client, logger }) => {
  await ack();

  const { ts, channel, reviewID, response } = JSON.parse(view.private_metadata);
  const approver = body.user.name;
  const adjustedDate = getGermanTime();

  try {
    if (!ts || !channel) {
      throw new Error("Missing 'ts' or 'channel' in private_metadata");
    }

    // Send the approved response to Retool
    await sendDataToRetool(reviewID, response);

    // Update the original message to replace buttons with approver info
    await client.chat.update({
      channel,
      ts,
      text: `Response approved by ${approver} on ${adjustedDate}`,
      blocks: [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `*Response approved by ${approver} on ${adjustedDate}*`
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `*AI response:*\n${response}`
          }
        }
      ]
    });

  } catch (error) {
    logger.error('Failed to send approved response', error);
  }
});

// Show the editing modal 
app.action('click_edit', async ({ body, ack, client, logger }) => {
  await ack();

  const reviewBlock = body.message.blocks.find(block => block.block_id === 'review_text');
  const review = reviewBlock ? reviewBlock.text.text : 'No review available'; 

  const responseBlock = body.message.blocks.find(block => block.block_id === 'response_text');
  const response = responseBlock ? responseBlock.text.text : 'No response available'; 

  const reviewIDBlock = body.message.blocks.find(block => block.block_id === 'review_id');
  const reviewID = reviewIDBlock ? reviewIDBlock.text.text : 'No review ID available'; 

  const privateMetadata = JSON.stringify({
    ts: body.message.ts,
    channel: body.channel.id,
    reviewID,
    response
  });

  try {
    await client.views.open({
      trigger_id: body.trigger_id,
      view: {
        "type": "modal",
        "callback_id": "edit_response_modal",
        "title": {
          "type": "plain_text",
          "text": "Edit Response",
          "emoji": true
        },
        "submit": {
          "type": "plain_text",
          "text": "Submit",
          "emoji": true
        },
        "close": {
          "type": "plain_text",
          "text": "Cancel",
          "emoji": true
        },
        "private_metadata": privateMetadata,
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "plain_text",
              "text": `Review ID: ${reviewID}`,
              "emoji": true
            }
          },
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": `*Review:*\n${review}`
            }
          },
          {
            "type": "input",
            "block_id": "response_block",
            "element": {
              "type": "plain_text_input",
              "multiline": true,
              "action_id": "plain_text_input-action",
              "initial_value": response
            },
            "label": {
              "type": "plain_text",
              "text": "Response:",
              "emoji": true
            }
          }
        ]
      }
    });

  } catch (error) {
    logger.error(error);
  }
});

// Handling submission of the edited response
app.view('edit_response_modal', async ({ ack, body, view, client, logger }) => {
  await ack();

  const { ts, channel, reviewID } = JSON.parse(view.private_metadata);
  const approver = body.user.name;
  const aiResponse = view.state.values.response_block['plain_text_input-action'].value;
  const adjustedDate = getGermanTime();

  try {
    if (!ts || !channel) {
      throw new Error("Missing 'ts' or 'channel' in private_metadata");
    }

    // Send the edited response to Retool
    await sendDataToRetool(reviewID, aiResponse);

    // Update the original message to replace buttons with approver info
    await client.chat.update({
      channel,
      ts,
      text: `Response submitted by ${approver} on ${adjustedDate}`,
      blocks: [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `*Response submitted by ${approver} on ${adjustedDate}*`
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `*Edited AI response:*\n${aiResponse}`
          }
        }
      ]
    });

  } catch (error) {
    logger.error('Failed to send edited response', error);
  }
});

// Function to send data to Retool
async function sendDataToRetool(reviewID, response) {
  const escapedResponse = response.replace(/'/g, "''");
  const payload = {
    "review_id": reviewID,
    "checked_response": escapedResponse
  };

  try {
    const res = await fetch('http://retool:8080/retool/v1/workflows/6dee29c1-37c2-40dd-8586-b52df9a63794/startTrigger', {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: {
        'Content-Type': 'application/json',
        'X-Workflow-Api-Key': `${process.env.RETOOL_API_KEY}`
      }
    });

    if (!res.ok) {
      const errorMessage = await res.text();
      throw new Error(`Failed to send data to Retool: ${errorMessage}`);
    }

  } catch (error) {
    console.error('Error sending data to Retool:', error); 
  }
}

(async () => {
  await app.start();
})();