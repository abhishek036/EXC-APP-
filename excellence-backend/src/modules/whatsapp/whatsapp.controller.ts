import { Request, Response } from 'express';
import crypto from 'crypto';
import dotenv from 'dotenv';
dotenv.config();

const timingSafeEquals = (a: string, b: string): boolean => {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
};

const hasValidMetaSignature = (req: Request): boolean => {
  const appSecret = process.env.WHATSAPP_APP_SECRET;
  if (!appSecret) {
    return process.env.NODE_ENV !== 'production';
  }

  const signature = String(req.headers['x-hub-signature-256'] || '').trim();
  if (!signature.startsWith('sha256=')) return false;

  const rawBody = String((req as any).rawBody || '');
  if (!rawBody) return false;

  const expected = `sha256=${crypto.createHmac('sha256', appSecret).update(rawBody).digest('hex')}`;
  return timingSafeEquals(signature, expected);
};

export class WhatsAppController {
  
  /**
   * GET /api/whatsapp/webhook
   * Meta sends a GET request to verify the webhook URL.
   */
  async verifyWebhook(req: Request, res: Response) {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    // This Verify Token should match what you type in the Meta Dashboard
    const verifyToken = process.env.WHATSAPP_VERIFY_TOKEN || 'excellence_secret_verify';

    if (mode && token) {
      if (mode === 'subscribe' && token === verifyToken) {
        console.log('✅ WhatsApp Webhook Verified successfully');
        return res.status(200).send(challenge);
      } else {
        return res.sendStatus(403);
      }
    }
    return res.status(400).send('Bad Request');
  }

  /**
   * POST /api/whatsapp/webhook
   * Meta sends a POST request whenever a message is sent, delivered, or received.
   */
  async receiveMessage(req: Request, res: Response) {
    try {
      if (!hasValidMetaSignature(req)) {
        return res.status(401).send('INVALID_SIGNATURE');
      }

      const entry = req.body.entry?.[0];
      const changes = entry?.changes?.[0];
      const value = changes?.value;
      const message = value?.messages?.[0];

      if (message) {
        const from = message.from;
        const messageType = message.type || 'unknown';
        const msgText = message.text?.body;
        console.log(`[WHATSAPP] Received ${messageType} message from ${from}: "${msgText || ''}"`);

        // Safe baseline behavior: capture intent keywords for observability.
        if (typeof msgText === 'string' && msgText.trim().length > 0) {
          const normalized = msgText.trim().toLowerCase();
          if (['hi', 'hello', 'help', 'support'].includes(normalized)) {
            console.log(`[WHATSAPP] Help intent detected from ${from}`);
          }
        }
      }

      // Always return 200 OK to Meta quickly to avoid retries
      res.status(200).send('EVENT_RECEIVED');
    } catch (err) {
      console.error('[WHATSAPP] Webhook Error:', err);
      res.sendStatus(500);
    }
  }
}

