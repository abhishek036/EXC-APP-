import { Router } from 'express';
import { WhatsAppController } from './whatsapp.controller';

const router = Router();
const controller = new WhatsAppController();

// GET for Meta Webhook Verification
router.get('/webhook', controller.verifyWebhook);

// POST for receiving WhatsApp messages / status updates
router.post('/webhook', controller.receiveMessage);

export default router;
