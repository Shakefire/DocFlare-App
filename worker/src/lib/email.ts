export interface EmailMessage {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export async function sendEmail(
  apiKey: string,
  from: string,
  message: EmailMessage
): Promise<void> {
  if (!apiKey || apiKey === 'test-email-key' || apiKey.startsWith('test-')) {
    console.log('[EMAIL MOCK] To:', message.to, 'Subject:', message.subject);
    return;
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        from: from || 'Docflare <noreply@docflare.app>',
        to: [message.to],
        subject: message.subject,
        html: message.html,
        text: message.text,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error('[EMAIL ERROR] Resend dispatch failed:', response.status, err);
    }
  } catch (err) {
    console.error('[EMAIL DISPATCH ERROR]', err);
  }
}

export function makeVerificationEmail(email: string, token: string, appName: string): EmailMessage {
  const link = `docflare://verify-email?token=${token}`;
  return {
    to: email,
    subject: `Verify your ${appName} email`,
    html: `
      <h2>Verify your email address</h2>
      <p>Thank you for registering with ${appName}.</p>
      <p>Please use this token in the app or tap the link below:</p>
      <p><strong>Token:</strong> <code>${token}</code></p>
      <p><a href="${link}">Verify Email Now</a></p>
      <p>This verification link will expire in 24 hours.</p>
    `,
    text: `Verify your ${appName} email with token: ${token} or open: ${link}`,
  };
}

export function makePasswordResetEmail(email: string, token: string, appName: string): EmailMessage {
  const link = `docflare://reset-password?token=${token}`;
  return {
    to: email,
    subject: `Reset your ${appName} password`,
    html: `
      <h2>Password Reset Request</h2>
      <p>We received a request to reset your password on ${appName}.</p>
      <p>Please use this token in the app or tap the link below:</p>
      <p><strong>Token:</strong> <code>${token}</code></p>
      <p><a href="${link}">Reset Password</a></p>
      <p>This reset token will expire in 1 hour. If you did not make this request, you can safely ignore this email.</p>
    `,
    text: `Reset your password for ${appName} with token: ${token} or open: ${link}`,
  };
}

export function makeInvitationEmail(
  email: string,
  token: string,
  orgName: string,
  role: string,
  appName: string
): EmailMessage {
  const link = `docflare://accept-invitation?token=${token}`;
  return {
    to: email,
    subject: `You've been invited to join ${orgName} on ${appName}`,
    html: `
      <h2>Organization Invitation</h2>
      <p>You have been invited to join <strong>${orgName}</strong> with the role of <strong>${role}</strong>.</p>
      <p><strong>Invitation Code:</strong> <code>${token}</code></p>
      <p><a href="${link}">Accept Invitation</a></p>
      <p>This invitation will expire in 7 days.</p>
    `,
    text: `You have been invited to ${orgName} as ${role}. Use token: ${token} or link: ${link}`,
  };
}
