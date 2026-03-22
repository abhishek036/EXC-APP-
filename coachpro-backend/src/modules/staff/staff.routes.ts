import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { StaffController } from './staff.controller';
import { createPayrollSchema, createStaffSchema } from './staff.validator';

const router = Router();
const controller = new StaffController();

router.use(authenticateJWT, tenantMiddleware);

router.get('/', requireRole('admin', 'teacher'), controller.listStaff);
router.post('/', requireRole('admin'), validate(createStaffSchema), controller.createStaff);
router.put('/:id', requireRole('admin'), controller.updateStaff);
router.delete('/:id', requireRole('admin'), controller.deleteStaff);

router.get('/payroll', requireRole('admin', 'teacher'), controller.listPayroll);
router.post('/payroll', requireRole('admin'), validate(createPayrollSchema), controller.createPayroll);

export default router;
