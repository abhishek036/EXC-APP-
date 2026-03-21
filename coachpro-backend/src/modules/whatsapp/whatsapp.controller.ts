import { Request, Response } from 'express';
import dotenv from 'dotenv';
dotenv.config();

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
    const verifyToken = process.env.WHATSAPP_VERIFY_TOKEN || 'coachpro_secret_verify';

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
      const entry = req.body.entry?.[0];
      const changes = entry?.changes?.[0];
      const value = changes?.value;
      const message = value?.messages?.[0];

      if (message) {
        const from = message.from;
        const msgText = message.text?.body;
        console.log(`[WHATSAPP] Received message from ${from}: "${msgText}"`);
        
        // TODO: Handle inbound messages (e.g. Chat bot, Auto-reply, Doubt submission)
      }

      // Always return 200 OK to Meta quickly to avoid retries
      res.status(200).send('EVENT_RECEIVED');
    } catch (err) {
      console.error('[WHATSAPP] Webhook Error:', err);
      res.sendStatus(500);
    }
  }
}
