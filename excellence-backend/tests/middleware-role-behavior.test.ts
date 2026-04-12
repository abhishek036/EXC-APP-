jest.mock('../src/server', () => ({
  prisma: {
    user: {
      findFirst: jest.fn(),
    },
  },
}));

import { requireRole } from '../src/middleware/auth.middleware';

describe('requireRole middleware behavior', () => {
  const run = (roles: string[], userRole: string) => {
    const middleware = requireRole(roles as any);
    const req: any = { user: { role: userRole } };
    const res: any = {};
    let forwardedError: any;
    const next = (err?: any) => {
      forwardedError = err;
    };

    middleware(req, res, next);
    return forwardedError;
  };

  test('does not allow super_user bypass unless explicitly listed', () => {
    const err = run(['admin'], 'super_user');
    expect(err).toBeTruthy();
    expect(err.statusCode).toBe(403);
  });

  test('allows explicitly permitted roles', () => {
    const err = run(['admin', 'teacher'], 'teacher');
    expect(err).toBeUndefined();
  });
});
