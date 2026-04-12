const updateAvatarMock = jest.fn();
const uploadSingleFileMock = jest.fn();

jest.mock('../src/modules/auth/auth.service', () => ({
  AuthService: jest.fn().mockImplementation(() => ({
    sendOtp: jest.fn(),
    verifyOtp: jest.fn(),
    loginWithPassword: jest.fn(),
    refreshToken: jest.fn(),
    logout: jest.fn(),
    getUserProfile: jest.fn(),
    changePassword: jest.fn(),
    resetPassword: jest.fn(),
    updateMe: jest.fn(),
    updateAvatar: updateAvatarMock,
  })),
}));

jest.mock('../src/modules/upload/upload.controller', () => ({
  UploadController: jest.fn().mockImplementation(() => ({
    uploadSingleFile: uploadSingleFileMock,
  })),
}));

import { AuthController } from '../src/modules/auth/auth.controller';

const createRes = () => {
  const res: any = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

describe('AuthController.updateAvatar', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('uploads avatar via UploadController and persists resulting URL', async () => {
    uploadSingleFileMock.mockResolvedValue({
      fileUrl: 'https://api.test/api/upload/file/ref_abc',
      storageProvider: 'b2',
      storageKey: 'avatars/u1.jpg',
      storageBucket: 'bucket',
      fileName: 'avatar.jpg',
      fileMimeType: 'image/jpeg',
      fileSizeKb: 12,
    });
    updateAvatarMock.mockResolvedValue({ avatar_url: 'https://api.test/api/upload/file/ref_abc' });

    const controller = new AuthController();
    const req: any = {
      file: {
        originalname: 'avatar.jpg',
        mimetype: 'image/jpeg',
        buffer: Buffer.from([0xff, 0xd8, 0xff]),
        size: 3,
      },
      protocol: 'https',
      get: jest.fn().mockReturnValue('api.test'),
      user: { userId: 'u1', role: 'student' },
    };
    const res = createRes();
    const next = jest.fn();

    await controller.updateAvatar(req, res, next);

    expect(uploadSingleFileMock).toHaveBeenCalledWith({
      file: req.file,
      destination: 'avatars',
      origin: 'https://api.test',
    });
    expect(updateAvatarMock).toHaveBeenCalledWith(
      'u1',
      'student',
      'https://api.test/api/upload/file/ref_abc',
    );

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Avatar updated successfully',
      }),
    );
  });

  it('forwards validation error when no file is provided', async () => {
    const controller = new AuthController();
    const req: any = {
      protocol: 'https',
      get: jest.fn().mockReturnValue('api.test'),
      user: { userId: 'u1', role: 'student' },
    };
    const res = createRes();
    const next = jest.fn();

    await controller.updateAvatar(req, res, next);

    expect(uploadSingleFileMock).not.toHaveBeenCalled();
    expect(updateAvatarMock).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({
        message: 'No image file provided',
        statusCode: 400,
      }),
    );
  });
});
