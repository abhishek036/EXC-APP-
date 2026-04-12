import { Request, Response, NextFunction } from 'express';
import { CertificateService } from './certificate.service';
import { sendResponse } from '../../utils/response';

export class CertificateController {
  private service: CertificateService;

  constructor() {
    this.service = new CertificateService();
  }

  mint = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.mintCertificate(req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Certificate minted successfully' });
    } catch (error) { next(error); }
  };

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { studentId } = req.query;
      const data = await this.service.listCertificates(req.instituteId!, { studentId: studentId as string });
      return sendResponse({ res, data, message: 'Certificates fetched' });
    } catch (error) { next(error); }
  };

  verify = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const cert = await this.service.verifyCertificate(req.params.cert_number);
      return sendResponse({ res, data: cert, message: 'Certificate verified' });
    } catch (error) { next(error); }
  };
}
