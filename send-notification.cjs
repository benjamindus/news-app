#!/usr/bin/env node
// Send push notification to all subscribers

const webpush = require('web-push');
const fs = require('fs');
const path = require('path');

const VAPID_PUBLIC = 'BEItfMYBHFrt7hwvOrgXd5B7P5GLtZ3fJTgle_IG_ex3KV82VNY1AqqBjbKnpxFSpFxMcbtYkIpZGe9UarNcoIE';
const VAPID_PRIVATE = 'vX6ztHQM2iPMF56SGFLoxrB0DgET7ORFi5lgAgQ96M0';

webpush.setVapidDetails(
  'mailto:ben.dus.email@gmail.com',
  VAPID_PUBLIC,
  VAPID_PRIVATE
);

const subscriptionsFile = path.join(__dirname, 'subscriptions.json');

function loadSubscriptions() {
  try {
    if (fs.existsSync(subscriptionsFile)) {
      return JSON.parse(fs.readFileSync(subscriptionsFile, 'utf8'));
    }
  } catch (e) {
    console.error('Error loading subscriptions:', e);
  }
  return [];
}

function saveSubscriptions(subs) {
  fs.writeFileSync(subscriptionsFile, JSON.stringify(subs, null, 2));
}

async function sendNotifications(title, body) {
  const subscriptions = loadSubscriptions();

  if (subscriptions.length === 0) {
    console.log('No subscribers yet.');
    return;
  }

  const payload = JSON.stringify({
    title: title || 'Briefing Ready',
    body: body || 'Your news briefing has been updated.',
    url: '/'
  });

  const validSubs = [];

  for (const sub of subscriptions) {
    try {
      await webpush.sendNotification(sub, payload);
      console.log('Notification sent successfully');
      validSubs.push(sub);
    } catch (error) {
      if (error.statusCode === 410 || error.statusCode === 404) {
        console.log('Subscription expired, removing...');
      } else {
        console.error('Error sending notification:', error);
        validSubs.push(sub); // Keep subscription on other errors
      }
    }
  }

  // Save only valid subscriptions
  saveSubscriptions(validSubs);
}

// Get title and body from command line args
const title = process.argv[2] || 'Briefing Ready';
const body = process.argv[3] || 'Your news briefing has been updated.';

sendNotifications(title, body);
