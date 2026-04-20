import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import {
    CreateNoteInput,
    UpdateNoteInput,
    CreateAssignmentInput,
    UpdateAssignmentInput,
    SubmitAssignmentInput,
    ReviewAssignmentSubmissionInput,
    CreateDoubtInput,
    RespondDoubtInput,
} from './content.validator';
import { isLegacyColumnError } from '../../utils/prisma-errors';
import { ApiError } from '../../middleware/error.middleware';
import { createHash } from 'crypto';

export class ContentRepository {
        private isPrismaSchemaDriftError(error: any): boolean {
            const code = String(error?.code || '').trim();
            return code === 'P2021' || code === 'P2022';
        }

    private isLegacyError(error: unknown, columnName?: string): boolean {
        return isLegacyColumnError(error, columnName);
    }

    private mapAssignmentRow(row: any) {
        return {
            id: row.id,
            batch_id: row.batch_id,
            institute_id: row.institute_id,
            teacher_id: row.teacher_id,
            title: row.title,
            subject: row.subject ?? null,
            description: row.description ?? null,
            instructions: row.instructions ?? null,
            max_marks: row.max_marks ?? null,
            due_date: row.due_date ?? null,
            file_url: row.file_url ?? null,
            allow_late_submission: row.allow_late_submission ?? false,
            late_grace_minutes: row.late_grace_minutes ?? 0,
            max_attempts: row.max_attempts ?? 1,
            allow_text_submission: row.allow_text_submission ?? true,
            allow_file_submission: row.allow_file_submission ?? true,
            max_file_size_kb: row.max_file_size_kb ?? 20480,
            allowed_file_types: Array.isArray(row.allowed_file_types)
              ? row.allowed_file_types
              : ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
            correct_solution_url: row.correct_solution_url ?? null,
            created_at: row.created_at ?? null,
            updated_at: row.updated_at ?? null,
        };
    }

        private mapNoteRow(row: any) {
            const type = this.normalizeNoteFileType(row.file_type, row.file_url, row.mime_type);
            const primaryFile = {
                id: row.file_id ?? null,
                file_url: row.file_url,
                file_name: row.file_name ?? this.fileNameFromUrl(row.file_url),
                file_type: type,
                mime_type: row.mime_type ?? null,
                file_size_kb: row.file_size_kb ?? null,
                storage_provider: row.storage_provider ?? null,
                storage_path: row.storage_path ?? null,
                version_no: row.version_no ?? 1,
            };

            const youtubeVisibility = this.youtubeVisibilityFromStorageProvider(
                primaryFile.storage_provider,
            );

            return {
                id: row.id,
                batch_id: row.batch_id,
                institute_id: row.institute_id,
                teacher_id: row.teacher_id,
                title: row.title,
                description: row.description ?? null,
                subject: row.subject ?? 'General',
                chapter_title: row.chapter_title ?? 'General',
                chapter_order: row.chapter_order ?? 0,
                file_url: row.file_url,
                file_type: type,
                file_size_kb: row.file_size_kb ?? null,
                created_at: row.created_at ?? null,
                updated_at: row.updated_at ?? null,
                downloads_count: row.downloads_count ?? 0,
                youtube_visibility: youtubeVisibility,
                primary_file: primaryFile,
                note_files: [primaryFile],
            };
        }

            private isYoutubeUrl(value?: string | null): boolean {
                const raw = String(value ?? '').trim();
                if (!raw) return false;
                try {
                const host = new URL(raw).host.toLowerCase();
                return host.includes('youtube.com')
                    || host.includes('youtu.be')
                    || host.includes('youtube-nocookie.com');
                } catch {
                return false;
                }
            }

            private normalizeYoutubeVisibility(value: unknown): 'public' | 'unlisted' | null {
                const normalized = String(value ?? '').trim().toLowerCase();
                if (normalized == 'public') return 'public';
                if (normalized == 'unlisted') return 'unlisted';
                return null;
            }

            private youtubeVisibilityFromStorageProvider(provider?: string | null): 'public' | 'unlisted' | null {
                const normalized = String(provider ?? '').trim().toLowerCase();
                if (normalized == 'youtube_public') return 'public';
                if (normalized == 'youtube_unlisted') return 'unlisted';
                return null;
            }

            private resolveStorageProvider(params: {
                explicitProvider?: string | null;
                fileType?: string | null;
                fileUrl?: string | null;
                youtubeVisibility?: 'public' | 'unlisted' | null;
            }): string | null {
                const explicitProvider = this.trimOrNull(params.explicitProvider);
                const fileType = String(params.fileType ?? '').trim().toLowerCase();
                const fileUrl = this.trimOrNull(params.fileUrl);

                if (
                fileType == 'video'
                && fileUrl
                && this.isYoutubeUrl(fileUrl)
                ) {
                const visibility = params.youtubeVisibility ?? 'unlisted';
                return `youtube_${visibility}`;
                }

                return explicitProvider;
            }

    private normalizeNoteFileType(type?: string | null, fileUrl?: string | null, mimeType?: string | null): string {
            const normalized = String(type ?? '').trim().toLowerCase();
            if (normalized) {
                if (['pdf', 'image', 'video', 'zip', 'doc', 'docx', 'ppt', 'pptx', 'other'].includes(normalized)) {
                    return normalized;
                }
            }

            const mime = String(mimeType ?? '').toLowerCase();
            if (mime.startsWith('image/')) return 'image';
            if (mime.startsWith('video/')) return 'video';
            if (mime.includes('pdf')) return 'pdf';
            if (mime.includes('zip')) return 'zip';
            if (mime.includes('word')) return 'docx';
            if (mime.includes('powerpoint') || mime.includes('presentation')) return 'pptx';

            const ext = this.extractExtension(fileUrl ?? undefined);
            if (!ext) return 'other';
            if (ext === 'pdf') return 'pdf';
            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext)) return 'image';
            if (['mp4', 'mov', 'avi', 'mkv', 'webm'].includes(ext)) return 'video';
            if (ext === 'zip') return 'zip';
            if (['doc', 'docx'].includes(ext)) return ext;
            if (['ppt', 'pptx'].includes(ext)) return ext;
            return 'other';
    }

    private fileNameFromUrl(fileUrl?: string | null): string {
            const raw = String(fileUrl ?? '').trim();
            if (!raw) return 'material';
            try {
                const uri = new URL(raw);
                const parts = uri.pathname.split('/').filter(Boolean);
                return decodeURIComponent(parts[parts.length - 1] || 'material');
            } catch {
                const clean = raw.split('?')[0];
                const parts = clean.split('/').filter(Boolean);
                return decodeURIComponent(parts[parts.length - 1] || 'material');
            }
    }

    private decodeUploadRef(fileUrl?: string | null): any | null {
            const raw = String(fileUrl ?? '').trim();
            if (!raw) return null;
            const marker = '/api/upload/file/';
            const idx = raw.indexOf(marker);
            if (idx < 0) return null;
            const keyRaw = raw.substring(idx + marker.length).split('?')[0];
            const key = decodeURIComponent(keyRaw);
            if (!key.startsWith('ref_')) return null;
            try {
                const json = Buffer.from(key.substring(4), 'base64url').toString('utf8');
                return JSON.parse(json);
            } catch {
                return null;
            }
    }

    private hashText(value: string): string {
            return createHash('sha256').update(value).digest('hex');
    }

  private extractExtension(value?: string | null): string | null {
      const raw = String(value ?? '').trim();
      if (!raw) return null;

      let pathCandidate = raw;
      try {
          pathCandidate = new URL(raw).pathname;
      } catch {
          pathCandidate = raw;
      }

      const withoutQuery = pathCandidate.split(/[?#]/)[0] ?? '';
      const fileName = withoutQuery.split('/').filter(Boolean).pop() ?? '';
      if (!fileName || !fileName.includes('.')) return null;

      const ext = fileName.split('.').pop()?.trim().toLowerCase() ?? '';
      if (!ext || !/^[a-z0-9]+$/.test(ext)) return null;
      return ext;
  }

  private normalizeFileTypes(value: unknown): string[] {
      const fallback = ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'];
      if (!Array.isArray(value) || value.length === 0) return fallback;
      const normalized = Array.from(new Set(value.map((item) => String(item).trim().toLowerCase()).filter(Boolean)));
      return normalized.length > 0 ? normalized : fallback;
  }

  private trimOrNull(value: unknown): string | null {
      const text = String(value ?? '').trim();
      return text.length > 0 ? text : null;
  }

  private toNumberOrNull(value: unknown): number | null {
      if (value === null || value === undefined || value === '') return null;
      const num = Number(value);
      return Number.isFinite(num) ? num : null;
  }

  private toIsoDateOrNull(value?: string | null): Date | null {
      if (!value) return null;
      const date = new Date(value);
      return Number.isFinite(date.getTime()) ? date : null;
  }

  private isLate(dueDate: Date | null, graceMinutes: number): boolean {
      if (!dueDate) return false;
      const graceMs = Math.max(0, graceMinutes || 0) * 60 * 1000;
      return Date.now() > (dueDate.getTime() + graceMs);
  }

  private ensureSubmissionFileRules(assignment: any, payload: SubmitAssignmentInput) {
      const text = this.trimOrNull(payload.submission_text);
      const fileUrl = this.trimOrNull(payload.file_url);
      const hasText = !!text;
      const hasFile = !!fileUrl;

      if (!payload.is_draft && !hasText && !hasFile) {
          throw new ApiError('Either text answer or file upload is required', 400, 'INVALID_SUBMISSION');
      }

      if (hasText && assignment.allow_text_submission === false) {
          throw new ApiError('Text submission is disabled for this assignment', 400, 'TEXT_SUBMISSION_DISABLED');
      }

      if (hasFile && assignment.allow_file_submission === false) {
          throw new ApiError('File submission is disabled for this assignment', 400, 'FILE_SUBMISSION_DISABLED');
      }

      const fileSizeKb = this.toNumberOrNull(payload.file_size_kb);
      if (hasFile && fileSizeKb !== null && assignment.max_file_size_kb && fileSizeKb > Number(assignment.max_file_size_kb)) {
          throw new ApiError(`File size exceeds ${assignment.max_file_size_kb}KB limit`, 400, 'FILE_TOO_LARGE');
      }

      const ext = this.trimOrNull((payload as any).file_ext)?.toLowerCase()
        ?? this.extractExtension((payload as any).file_name)
        ?? this.extractExtension(fileUrl);

      if (hasFile && ext) {
          const allowed = this.normalizeFileTypes(assignment.allowed_file_types);
          if (!allowed.includes(ext)) {
              throw new ApiError(`File type .${ext} is not allowed for this assignment`, 400, 'INVALID_FILE_TYPE');
          }
      }

      if ((payload as any).scan_status === 'infected') {
          throw new ApiError('Blocked unsafe file upload', 400, 'MALWARE_DETECTED');
      }
  }

    private mergeSubmissionPayload(payload: SubmitAssignmentInput, fallback?: any) {
            const fileUrl = this.trimOrNull(payload.file_url) ?? this.trimOrNull(fallback?.file_url);
            const text = this.trimOrNull(payload.submission_text) ?? this.trimOrNull(fallback?.submission_text);
            const fileName = this.trimOrNull((payload as any).file_name) ?? this.trimOrNull(fallback?.file_name);
            const fileMimeType = this.trimOrNull((payload as any).file_mime_type) ?? this.trimOrNull(fallback?.file_mime_type);
            const fileSizeKb = this.toNumberOrNull((payload as any).file_size_kb) ?? this.toNumberOrNull(fallback?.file_size_kb);
            const scanStatus = this.trimOrNull((payload as any).scan_status)
                ?? this.trimOrNull(fallback?.scan_status)
                ?? (fileUrl ? 'pending' : 'clean');

            return {
                file_url: fileUrl,
                submission_text: text,
                file_name: fileName,
                file_mime_type: fileMimeType,
                file_size_kb: fileSizeKb,
                scan_status: scanStatus,
            };
    }

    // NOTES
        async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
            const chapterTitle = this.trimOrNull((data as any).chapter_title) ?? 'General';
            const chapterOrder = Number((data as any).chapter_order ?? 0);
            const requestedYoutubeVisibility = this.normalizeYoutubeVisibility(
                (data as any).youtube_visibility,
            );

            const payloadFiles: any[] = Array.isArray((data as any).note_files)
                ? (data as any).note_files
                : [];

            if ((data as any).file_url) {
                payloadFiles.unshift({
                    file_url: (data as any).file_url,
                    file_name: null,
                    file_type: (data as any).file_type,
                    mime_type: null,
                    file_size_kb: (data as any).file_size_kb,
                });
            }

            const normalizedFiles = payloadFiles
                .map((file) => {
                    const fileUrl = this.trimOrNull(file.file_url);
                    if (!fileUrl) return null;

                    const storageMeta = this.decodeUploadRef(fileUrl);
                    const fileName = this.trimOrNull(file.file_name)
                        ?? storageMeta?.fileName
                        ?? this.fileNameFromUrl(fileUrl);

                    const fileType = this.normalizeNoteFileType(file.file_type, fileUrl, file.mime_type ?? storageMeta?.mimeType);
                    const fileHash = this.trimOrNull(file.file_hash)
                        ?? this.hashText(`${fileUrl}|${fileName}`);
                    const baseStorageProvider = this.trimOrNull(file.storage_provider)
                        ?? this.trimOrNull(storageMeta?.provider)
                        ?? (fileUrl.includes('/api/upload/file/') ? 'b2' : 'external');

                    return {
                        file_url: fileUrl,
                        file_name: fileName,
                        file_type: fileType,
                        mime_type: this.trimOrNull(file.mime_type) ?? this.trimOrNull(storageMeta?.mimeType),
                        file_size_kb: this.toNumberOrNull(file.file_size_kb) ?? this.toNumberOrNull(storageMeta?.sizeKb),
                        storage_provider: this.resolveStorageProvider(
                            {
                                explicitProvider: baseStorageProvider,
                                fileType,
                                fileUrl,
                                youtubeVisibility: requestedYoutubeVisibility,
                            },
                        ),
                        storage_path: this.trimOrNull(file.storage_path)
                            ?? this.trimOrNull(storageMeta?.key)
                            ?? fileUrl,
                        file_hash: fileHash,
                    };
                })
                .filter((item): item is any => item !== null);

            const dedupedFiles = Array.from(
                new Map(normalizedFiles.map((file) => [file.file_hash, file])).values(),
            );

            if (dedupedFiles.length === 0) {
                throw new ApiError('At least one valid note file is required', 400, 'NOTE_FILE_REQUIRED');
            }

            return prisma.$transaction(async (tx) => {
                const firstFile = dedupedFiles[0];
                const note = await tx.note.create({
                    data: {
                        institute_id: instituteId,
                        teacher_id: teacherId ?? null,
                        batch_id: data.batch_id,
                        title: data.title,
                        subject: this.trimOrNull(data.subject) ?? 'General',
                        description: this.trimOrNull((data as any).description),
                        chapter_title: chapterTitle,
                        chapter_order: Number.isFinite(chapterOrder) ? chapterOrder : 0,
                        file_url: firstFile.file_url,
                        file_type: firstFile.file_type,
                        file_size_kb: firstFile.file_size_kb,
                    } as any,
                });

                await tx.noteFile.createMany({
                    data: dedupedFiles.map((file) => ({
                        note_id: note.id,
                        institute_id: instituteId,
                        file_url: file.file_url,
                        file_name: file.file_name,
                        file_type: file.file_type,
                        mime_type: file.mime_type,
                        file_size_kb: file.file_size_kb,
                        storage_provider: file.storage_provider,
                        storage_path: file.storage_path,
                        file_hash: file.file_hash,
                        version_no: 1,
                        is_latest: true,
                    })),
                });

                const created = await tx.note.findUnique({
                    where: { id: note.id },
                    include: {
                        note_files: {
                            where: { is_deleted: false, is_latest: true },
                            orderBy: [{ version_no: 'desc' }, { created_at: 'desc' }],
                        },
                        _count: { select: { download_logs: true, bookmarks: true } },
                    },
                });

                return {
                    ...created,
                    downloads_count: created?._count?.download_logs ?? 0,
                    bookmarks_count: created?._count?.bookmarks ?? 0,
                    primary_file: created?.note_files?.[0] ?? null,
                    youtube_visibility: this.youtubeVisibilityFromStorageProvider(
                        created?.note_files?.[0]?.storage_provider,
                    ),
                };
            });
    }

    async listNotes(instituteId: string, filter: { batchId?: string, subject?: string, chapterTitle?: string, includeDeleted?: boolean }) {
            try {
                    const rows = await prisma.note.findMany({
                            where: {
                                institute_id: instituteId,
                                ...(filter.batchId && { batch_id: filter.batchId }),
                                ...(filter.subject && { subject: filter.subject }),
                                ...(filter.chapterTitle && { chapter_title: filter.chapterTitle }),
                                ...(filter.includeDeleted ? {} : { is_deleted: false }),
                            },
                            include: {
                                note_files: {
                                    where: { is_deleted: false, is_latest: true },
                                    orderBy: [{ version_no: 'desc' }, { created_at: 'desc' }],
                                },
                                _count: { select: { download_logs: true, bookmarks: true } },
                            },
                            orderBy: [
                                { subject: 'asc' },
                                { chapter_order: 'asc' },
                                { created_at: 'desc' },
                            ],
                    });

                    return rows.map((row: any) => ({
                        ...row,
                        downloads_count: row?._count?.download_logs ?? 0,
                        bookmarks_count: row?._count?.bookmarks ?? 0,
                        primary_file: Array.isArray(row.note_files) && row.note_files.length > 0 ? row.note_files[0] : null,
                        youtube_visibility: this.youtubeVisibilityFromStorageProvider(
                            Array.isArray(row.note_files) && row.note_files.length > 0
                                ? row.note_files[0]?.storage_provider
                                : null,
                        ),
                    }));
            } catch (error) {
                    if (!this.isLegacyError(error)) throw error;
                    return this.listNotesLegacy(instituteId, filter);
            }
    }

    private async listNotesLegacy(instituteId: string, filter: { batchId?: string, subject?: string, chapterTitle?: string, includeDeleted?: boolean }) {
            // Fallback for older schemas missing note files and chapter columns.
            const batchIdParam = filter.batchId ?? null;
            const rows = await prisma.$queryRaw<any[]>(Prisma.sql`
                SELECT id::text,
                   title,
                   NULL::text as description,
                   'General'::text as subject,
                   'General'::text as chapter_title,
                   0 as chapter_order,
                   file_url,
                   COALESCE(file_type, 'other') as file_type,
                   file_size_kb,
                   created_at,
                   batch_id::text,
                   institute_id::text,
                   teacher_id::text
                FROM notes
                WHERE institute_id::text = ${instituteId}::text
                  AND (${batchIdParam}::text IS NULL OR batch_id::text = ${batchIdParam}::text)
                ORDER BY created_at DESC
            `);

            return rows.map((row) => this.mapNoteRow(row));
    }

    async getNoteById(instituteId: string, noteId: string) {
            return prisma.note.findFirst({
                    where: {
                        id: noteId,
                        institute_id: instituteId,
                        is_deleted: false,
                    },
                    include: {
                        note_files: {
                            where: { is_deleted: false, is_latest: true },
                            orderBy: [{ version_no: 'desc' }, { created_at: 'desc' }],
                        },
                        _count: { select: { download_logs: true, bookmarks: true } },
                    },
            });
    }

    async updateNote(instituteId: string, noteId: string, data: UpdateNoteInput) {
            const existing = await prisma.note.findFirst({
                where: {
                    id: noteId,
                    institute_id: instituteId,
                    is_deleted: false,
                },
            });

            if (!existing) {
                throw new ApiError('Note not found', 404, 'NOT_FOUND');
            }

            const updateData: any = {};
            if ((data as any).title !== undefined) updateData.title = data.title;
            if ((data as any).batch_id !== undefined) updateData.batch_id = (data as any).batch_id;
            if ((data as any).subject !== undefined) {
                updateData.subject = this.trimOrNull((data as any).subject) ?? 'General';
            }
            if ((data as any).description !== undefined) {
                updateData.description = this.trimOrNull((data as any).description);
            }
            if ((data as any).chapter_title !== undefined) {
                updateData.chapter_title = this.trimOrNull((data as any).chapter_title) ?? 'General';
            }
            if ((data as any).chapter_order !== undefined) {
                const chapterOrder = Number((data as any).chapter_order ?? 0);
                updateData.chapter_order = Number.isFinite(chapterOrder) ? chapterOrder : 0;
            }

            const incomingFileUrlRaw = (data as any).file_url;
            const incomingFileUrl = this.trimOrNull(incomingFileUrlRaw);
            const hasFileUpdate = incomingFileUrlRaw !== undefined && !!incomingFileUrl;
            const requestedYoutubeVisibility = this.normalizeYoutubeVisibility(
                (data as any).youtube_visibility,
            );

            if (hasFileUpdate) {
                const fileType = this.normalizeNoteFileType((data as any).file_type, incomingFileUrl);
                updateData.file_url = incomingFileUrl;
                updateData.file_type = fileType;
                updateData.file_size_kb = this.toNumberOrNull((data as any).file_size_kb);
            } else {
                if ((data as any).file_type !== undefined) {
                    updateData.file_type = this.normalizeNoteFileType(
                        (data as any).file_type,
                        existing.file_url,
                    );
                }
                if ((data as any).file_size_kb !== undefined) {
                    updateData.file_size_kb = this.toNumberOrNull((data as any).file_size_kb);
                }
            }

            try {
                return await prisma.$transaction(async (tx) => {
                    if (Object.keys(updateData).length > 0) {
                        await tx.note.update({
                            where: { id: noteId },
                            data: updateData,
                        });
                    }

                    if (hasFileUpdate) {
                        await tx.noteFile.updateMany({
                            where: {
                                note_id: noteId,
                                institute_id: instituteId,
                                is_deleted: false,
                                is_latest: true,
                            },
                            data: {
                                is_latest: false,
                            },
                        });

                        const version = await tx.noteFile.aggregate({
                            where: {
                                note_id: noteId,
                                institute_id: instituteId,
                            },
                            _max: { version_no: true },
                        });

                        const storageMeta = this.decodeUploadRef(incomingFileUrl);
                        const fileName = storageMeta?.fileName ?? this.fileNameFromUrl(incomingFileUrl);
                        const fileType = this.normalizeNoteFileType(
                            (data as any).file_type,
                            incomingFileUrl,
                            storageMeta?.mimeType,
                        );
                        const nextVersionNo = Number(version._max.version_no ?? 0) + 1;
                        const baseStorageProvider =
                            this.trimOrNull(storageMeta?.provider)
                            ?? (incomingFileUrl.includes('/api/upload/file/') ? 'b2' : 'external');

                        await tx.noteFile.create({
                            data: {
                                note_id: noteId,
                                institute_id: instituteId,
                                file_url: incomingFileUrl,
                                file_name: fileName,
                                file_type: fileType,
                                mime_type: this.trimOrNull(storageMeta?.mimeType),
                                file_size_kb:
                                    this.toNumberOrNull((data as any).file_size_kb) ??
                                    this.toNumberOrNull(storageMeta?.sizeKb),
                                storage_provider: this.resolveStorageProvider({
                                    explicitProvider: baseStorageProvider,
                                    fileType,
                                    fileUrl: incomingFileUrl,
                                    youtubeVisibility: requestedYoutubeVisibility,
                                }),
                                storage_path:
                                    this.trimOrNull(storageMeta?.key) ?? incomingFileUrl,
                                file_hash: this.hashText(
                                    `${incomingFileUrl}|${fileName}|${nextVersionNo}`,
                                ),
                                version_no: nextVersionNo,
                                is_latest: true,
                            },
                        });
                    } else if (requestedYoutubeVisibility != null) {
                        const latestFiles = await tx.noteFile.findMany({
                            where: {
                                note_id: noteId,
                                institute_id: instituteId,
                                is_deleted: false,
                                is_latest: true,
                            },
                            select: {
                                id: true,
                                file_url: true,
                                file_type: true,
                                storage_provider: true,
                            },
                        });

                        for (const file of latestFiles) {
                            const fileType = this.normalizeNoteFileType(file.file_type, file.file_url);
                            if (fileType != 'video' || !this.isYoutubeUrl(file.file_url)) {
                                continue;
                            }

                            await tx.noteFile.update({
                                where: { id: file.id },
                                data: {
                                    storage_provider: this.resolveStorageProvider({
                                        explicitProvider: file.storage_provider,
                                        fileType,
                                        fileUrl: file.file_url,
                                        youtubeVisibility: requestedYoutubeVisibility,
                                    }),
                                },
                            });
                        }
                    }

                    const updated = await tx.note.findFirst({
                        where: {
                            id: noteId,
                            institute_id: instituteId,
                        },
                        include: {
                            note_files: {
                                where: { is_deleted: false, is_latest: true },
                                orderBy: [{ version_no: 'desc' }, { created_at: 'desc' }],
                            },
                            _count: { select: { download_logs: true, bookmarks: true } },
                        },
                    });

                    return {
                        ...updated,
                        downloads_count: updated?._count?.download_logs ?? 0,
                        bookmarks_count: updated?._count?.bookmarks ?? 0,
                        primary_file:
                            Array.isArray(updated?.note_files) && updated.note_files.length > 0
                                ? updated.note_files[0]
                                : null,
                        youtube_visibility: this.youtubeVisibilityFromStorageProvider(
                            Array.isArray(updated?.note_files) && updated.note_files.length > 0
                                ? updated.note_files[0]?.storage_provider
                                : null,
                        ),
                    };
                });
            } catch (error) {
                if (!this.isLegacyError(error)) throw error;

                if (Object.keys(updateData).length > 0) {
                    await prisma.note.updateMany({
                        where: { id: noteId, institute_id: instituteId, is_deleted: false },
                        data: updateData,
                    });
                }

                                const rows = await prisma.$queryRaw<any[]>(Prisma.sql`
                                        SELECT id::text,
                                                     title,
                                                     COALESCE(description, '') as description,
                                                     COALESCE(subject, 'General') as subject,
                                                     COALESCE(chapter_title, 'General') as chapter_title,
                                                     COALESCE(chapter_order, 0) as chapter_order,
                                                     file_url,
                                                     COALESCE(file_type, 'other') as file_type,
                                                     file_size_kb,
                                                     created_at,
                                                     batch_id::text,
                                                     institute_id::text,
                                                     teacher_id::text
                                        FROM notes
                                        WHERE id::text = ${noteId}::text
                                            AND institute_id::text = ${instituteId}::text
                                `);

                if (!rows.length) {
                    throw new ApiError('Note not found', 404, 'NOT_FOUND');
                }

                return this.mapNoteRow(rows[0]);
            }
    }

    async getNoteFile(instituteId: string, noteId: string, fileId: string) {
            return prisma.noteFile.findFirst({
                where: {
                    id: fileId,
                    note_id: noteId,
                    institute_id: instituteId,
                    is_deleted: false,
                    note: {
                        id: noteId,
                        institute_id: instituteId,
                        is_deleted: false,
                    },
                },
                include: {
                    note: {
                        select: {
                            id: true,
                            title: true,
                            batch_id: true,
                            teacher_id: true,
                            institute_id: true,
                            is_deleted: true,
                        },
                    },
                },
            });
    }

    async bookmarkNote(instituteId: string, noteId: string, studentId: string) {
            return prisma.noteBookmark.upsert({
                where: { note_id_student_id: { note_id: noteId, student_id: studentId } },
                update: {},
                create: {
                    institute_id: instituteId,
                    note_id: noteId,
                    student_id: studentId,
                },
            });
    }

    async unbookmarkNote(instituteId: string, noteId: string, studentId: string) {
            const result = await prisma.noteBookmark.deleteMany({
                where: {
                    institute_id: instituteId,
                    note_id: noteId,
                    student_id: studentId,
                },
            });
            return { deleted_count: result.count };
    }

    async listBookmarkedNotes(instituteId: string, studentId: string, filter: { batchId?: string, subject?: string }) {
            let rows: any[] = [];
            try {
                rows = await prisma.noteBookmark.findMany({
                    where: {
                        institute_id: instituteId,
                        student_id: studentId,
                        note: {
                            is_deleted: false,
                            ...(filter.batchId && { batch_id: filter.batchId }),
                            ...(filter.subject && { subject: filter.subject }),
                        },
                    },
                    include: {
                        note: {
                            include: {
                                note_files: {
                                    where: { is_deleted: false, is_latest: true },
                                    orderBy: [{ version_no: 'desc' }, { created_at: 'desc' }],
                                },
                                _count: { select: { download_logs: true, bookmarks: true } },
                            },
                        },
                    },
                    orderBy: { created_at: 'desc' },
                });
            } catch (error) {
                if (!this.isPrismaSchemaDriftError(error)) {
                    throw error;
                }
                rows = [];
            }

            return rows.map((row: any) => ({
                ...row.note,
                is_bookmarked: true,
                downloads_count: row.note?._count?.download_logs ?? 0,
                bookmarks_count: row.note?._count?.bookmarks ?? 0,
                primary_file: Array.isArray(row.note?.note_files) && row.note.note_files.length > 0 ? row.note.note_files[0] : null,
            }));
    }

    async listStudentBookmarksMap(instituteId: string, studentId: string, noteIds: string[]) {
            if (!noteIds.length) return new Set<string>();
            let rows: Array<{ note_id: string }> = [];
            try {
                rows = await prisma.noteBookmark.findMany({
                    where: {
                        institute_id: instituteId,
                        student_id: studentId,
                        note_id: { in: noteIds },
                    },
                    select: { note_id: true },
                });
            } catch (error) {
                if (!this.isPrismaSchemaDriftError(error)) {
                    throw error;
                }
                rows = [];
            }
            return new Set(rows.map((item) => String(item.note_id)));
    }

    async logNoteAccess(params: {
            instituteId: string;
            noteId: string;
            noteFileId?: string | null;
            studentId?: string | null;
            action: 'view' | 'download';
            ipAddress?: string | null;
            userAgent?: string | null;
    }) {
            return prisma.downloadLog.create({
                    data: {
                        institute_id: params.instituteId,
                        note_id: params.noteId,
                        note_file_id: params.noteFileId ?? null,
                        student_id: params.studentId ?? null,
                        action: params.action,
                        ip_address: params.ipAddress ?? null,
                        user_agent: params.userAgent ?? null,
                    },
            });
    }

    async getNotesAnalytics(instituteId: string, filter: { batchId?: string, subject?: string, chapterTitle?: string, teacherId?: string }) {
            const notes = await prisma.note.findMany({
                where: {
                    institute_id: instituteId,
                    is_deleted: false,
                    ...(filter.batchId && { batch_id: filter.batchId }),
                    ...(filter.subject && { subject: filter.subject }),
                    ...(filter.chapterTitle && { chapter_title: filter.chapterTitle }),
                    ...(filter.teacherId && { teacher_id: filter.teacherId }),
                },
                include: {
                    _count: { select: { download_logs: true, bookmarks: true } },
                    download_logs: {
                        where: { student_id: { not: null } },
                        select: { student_id: true },
                    },
                },
            });

            const noteIds = notes.map((item) => item.id);
            const logs = noteIds.length > 0
                ? await prisma.downloadLog.findMany({
                    where: {
                        institute_id: instituteId,
                        note_id: { in: noteIds },
                    },
                    select: {
                        note_id: true,
                        student_id: true,
                        action: true,
                    },
                })
                : [];

            const downloads = logs.filter((item) => item.action === 'download');
            const views = logs.filter((item) => item.action === 'view');
            const uniqueStudents = new Set(logs.map((item) => item.student_id).filter(Boolean));

            const byNote = notes.map((note) => {
                const noteLogs = logs.filter((item) => item.note_id === note.id);
                const noteDownloads = noteLogs.filter((item) => item.action === 'download').length;
                const noteViews = noteLogs.filter((item) => item.action === 'view').length;
                const engagedStudents = new Set(noteLogs.map((item) => item.student_id).filter(Boolean));
                return {
                    note_id: note.id,
                    title: note.title,
                    subject: note.subject,
                    chapter_title: note.chapter_title,
                    views_count: noteViews,
                    downloads_count: noteDownloads,
                    bookmarks_count: note._count.bookmarks,
                    engagement_students: engagedStudents.size,
                };
            }).sort((a, b) => b.views_count - a.views_count);

            return {
                notes_count: notes.length,
                total_views: views.length,
                total_downloads: downloads.length,
                unique_student_engagement: uniqueStudents.size,
                most_viewed_notes: byNote.slice(0, 10),
            };
    }

    async softDeleteNote(instituteId: string, noteId: string) {
            return prisma.$transaction(async (tx) => {
                await tx.noteFile.updateMany({
                    where: {
                        note_id: noteId,
                        institute_id: instituteId,
                        is_deleted: false,
                    },
                    data: {
                        is_deleted: true,
                        is_latest: false,
                    },
                });

                const result = await tx.note.updateMany({
                    where: {
                        id: noteId,
                        institute_id: instituteId,
                        is_deleted: false,
                    },
                    data: {
                        is_deleted: true,
                        deleted_at: new Date(),
                        updated_at: new Date(),
                    },
                });

                if (result.count === 0) {
                    throw new ApiError('Note not found', 404, 'NOT_FOUND');
                }

                return tx.note.findFirst({
                    where: {
                        id: noteId,
                        institute_id: instituteId,
                    },
                });
            });
    }

  // ASSIGNMENTS
  async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      const assignmentData: any = {
          title: data.title,
          description: this.trimOrNull(data.description),
          instructions: this.trimOrNull((data as any).instructions),
          batch_id: data.batch_id,
          subject: this.trimOrNull(data.subject),
          file_url: this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url),
          max_marks: this.toNumberOrNull((data as any).max_marks),
          due_date: this.toIsoDateOrNull(data.due_date),
          allow_late_submission: (data as any).allow_late_submission ?? false,
          late_grace_minutes: Number((data as any).late_grace_minutes ?? 0),
          max_attempts: Number((data as any).max_attempts ?? 1),
          allow_text_submission: (data as any).allow_text_submission ?? true,
          allow_file_submission: (data as any).allow_file_submission ?? true,
          max_file_size_kb: Number((data as any).max_file_size_kb ?? 20480),
          allowed_file_types: this.normalizeFileTypes((data as any).allowed_file_types),
          correct_solution_url: this.trimOrNull((data as any).correct_solution_url),
          institute_id: instituteId,
          teacher_id: teacherId ?? null,
      };

      try {
          return await prisma.assignment.create({
              data: assignmentData
          });
      } catch (error) {
          if (!this.isLegacyError(error)) throw error;
          return this.createAssignmentLegacy(instituteId, teacherId, data);
      }
  }

  async listAssignments(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      try {
          return await prisma.assignment.findMany({
              where: { 
                institute_id: instituteId, 
                ...(filter.batchId && { batch_id: filter.batchId }),
                ...(filter.teacherId && { teacher_id: filter.teacherId }),
                ...(filter.subject && { subject: filter.subject })
              },
              orderBy: { created_at: 'desc' }
          });
      } catch (error) {
                    if (!this.isLegacyError(error)) throw error;
          return this.listAssignmentsLegacy(instituteId, {
            batchId: filter.batchId,
            teacherId: filter.teacherId,
          });
      }
  }

  async updateAssignment(instituteId: string, assignmentId: string, data: UpdateAssignmentInput) {
      const updateData: any = {
          ...(data.title !== undefined ? { title: data.title } : {}),
          ...(data.description !== undefined ? { description: this.trimOrNull(data.description) } : {}),
          ...((data as any).instructions !== undefined ? { instructions: this.trimOrNull((data as any).instructions) } : {}),
          ...(data.batch_id !== undefined ? { batch_id: data.batch_id } : {}),
          ...(data.subject !== undefined ? { subject: this.trimOrNull(data.subject) } : {}),
          ...((data as any).question_file_url !== undefined || data.file_url !== undefined
              ? { file_url: this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url) }
              : {}),
          ...((data as any).max_marks !== undefined ? { max_marks: this.toNumberOrNull((data as any).max_marks) } : {}),
          ...(data.due_date !== undefined ? { due_date: this.toIsoDateOrNull(data.due_date) } : {}),
          ...((data as any).allow_late_submission !== undefined ? { allow_late_submission: (data as any).allow_late_submission } : {}),
          ...((data as any).late_grace_minutes !== undefined ? { late_grace_minutes: Number((data as any).late_grace_minutes ?? 0) } : {}),
          ...((data as any).max_attempts !== undefined ? { max_attempts: Number((data as any).max_attempts ?? 1) } : {}),
          ...((data as any).allow_text_submission !== undefined ? { allow_text_submission: (data as any).allow_text_submission } : {}),
          ...((data as any).allow_file_submission !== undefined ? { allow_file_submission: (data as any).allow_file_submission } : {}),
          ...((data as any).max_file_size_kb !== undefined ? { max_file_size_kb: Number((data as any).max_file_size_kb ?? 20480) } : {}),
          ...((data as any).allowed_file_types !== undefined ? { allowed_file_types: this.normalizeFileTypes((data as any).allowed_file_types) } : {}),
          ...((data as any).correct_solution_url !== undefined ? { correct_solution_url: this.trimOrNull((data as any).correct_solution_url) } : {}),
      };

      if (Object.keys(updateData).length === 0) {
          const existing = await prisma.assignment.findFirst({
              where: { id: assignmentId, institute_id: instituteId },
          });
          if (!existing) throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
          return existing;
      }

      try {
          const result = await prisma.assignment.updateMany({
              where: { id: assignmentId, institute_id: instituteId },
              data: updateData,
          });

          if (result.count === 0) {
              throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
          }

          return prisma.assignment.findFirst({
              where: { id: assignmentId, institute_id: instituteId },
          });
      } catch (error) {
          if (!this.isLegacyError(error)) throw error;
          return this.updateAssignmentLegacy(instituteId, assignmentId, data);
      }
  }

  private async updateAssignmentLegacy(instituteId: string, assignmentId: string, data: UpdateAssignmentInput) {
      const currentRows = await prisma.$queryRaw<any[]>(Prisma.sql`
          SELECT id::text, title, description, due_date, file_url, created_at, batch_id::text
          FROM assignments
          WHERE id::text = ${assignmentId}::text AND institute_id::text = ${instituteId}::text
      `);

      if (!currentRows.length) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      const current = currentRows[0];
      const nextTitle = data.title ?? current.title;
      const nextDescription = this.trimOrNull(data.description) ?? current.description;
      const nextDueDate = data.due_date ? new Date(data.due_date).toISOString() : current.due_date;
      const nextFileUrl = this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url) ?? current.file_url;

      await prisma.$executeRaw(Prisma.sql`
          UPDATE assignments
          SET title = ${nextTitle},
              description = ${nextDescription},
              due_date = ${nextDueDate}::timestamp,
              file_url = ${nextFileUrl},
              updated_at = NOW()
          WHERE id::text = ${assignmentId}::text
            AND institute_id::text = ${instituteId}::text
      `);

      const rows = await prisma.$queryRaw<any[]>(Prisma.sql`
          SELECT id::text, title, description, due_date, file_url, created_at, batch_id::text
          FROM assignments
          WHERE id::text = ${assignmentId}::text AND institute_id::text = ${instituteId}::text
      `);

      return this.mapAssignmentRow(rows[0]);
  }

  async deleteAssignment(instituteId: string, assignmentId: string) {
      const result = await prisma.assignment.deleteMany({
          where: { id: assignmentId, institute_id: instituteId },
      });

      if (result.count === 0) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      return { id: assignmentId, deleted: true };
  }

  private async createAssignmentLegacy(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      // Manual SQL insert avoiding columns that might not exist in production
      const id = crypto.randomUUID();
      const dueDate = data.due_date ? new Date(data.due_date).toISOString() : null;
      const fileUrl = this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url);
      
      await prisma.$executeRaw(Prisma.sql`
          INSERT INTO assignments (id, institute_id, teacher_id, batch_id, title, description, file_url, due_date, created_at)
          VALUES (${id}::uuid, ${instituteId}::uuid, ${teacherId}::uuid, ${data.batch_id}::uuid, ${data.title}, ${this.trimOrNull(data.description)}, ${fileUrl}, ${dueDate}::timestamp, NOW())
      `);
      
      return {
        id,
        ...data,
        file_url: fileUrl,
        institute_id: instituteId,
        teacher_id: teacherId,
        allow_late_submission: false,
        late_grace_minutes: 0,
        max_attempts: 1,
        allow_text_submission: true,
        allow_file_submission: true,
        max_file_size_kb: 20480,
        allowed_file_types: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      };
  }

  private async listAssignmentsLegacy(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      const batchIdParam = filter.batchId ?? null;
      const teacherIdParam = filter.teacherId ?? null;
      const rows = await prisma.$queryRaw<any[]>(Prisma.sql`
          SELECT id::text, title, description, due_date, file_url, created_at, batch_id::text
          FROM assignments
          WHERE institute_id::text = ${instituteId}::text
            AND (${batchIdParam}::text IS NULL OR batch_id::text = ${batchIdParam}::text)
            AND (${teacherIdParam}::text IS NULL OR teacher_id::text = ${teacherIdParam}::text)
      `);
      return rows.map((row) => this.mapAssignmentRow(row));
  }

  async saveAssignmentDraft(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      const assignment = await prisma.assignment.findFirst({
          where: { id: assignmentId, institute_id: instituteId },
          select: {
              id: true,
              due_date: true,
              allow_late_submission: true,
              late_grace_minutes: true,
              max_attempts: true,
              allow_text_submission: true,
              allow_file_submission: true,
              max_file_size_kb: true,
              allowed_file_types: true,
          },
      });

      if (!assignment) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      const payload = { ...(data as any), is_draft: true } as SubmitAssignmentInput;
      this.ensureSubmissionFileRules(assignment, payload);

      const dueDate = assignment.due_date ? new Date(assignment.due_date as any) : null;
      const isLateNow = this.isLate(dueDate, Number(assignment.late_grace_minutes ?? 0));
      if (isLateNow && assignment.allow_late_submission === false) {
          throw new ApiError('Deadline has passed. Draft cannot be edited now.', 400, 'DEADLINE_PASSED');
      }

      const maxAttempts = Math.max(1, Number(assignment.max_attempts ?? 1));
      const now = new Date();
      const latest = await prisma.assignmentSubmission.findFirst({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          orderBy: { attempt_no: 'desc' },
      });

      if (latest?.is_draft) {
          const merged = this.mergeSubmissionPayload(payload, latest);
          return prisma.assignmentSubmission.update({
              where: { id: latest.id },
              data: {
                  ...merged,
                  status: 'in_progress',
                  draft_saved_at: now,
                  submitted_at: null,
                  is_draft: true,
                  is_late: false,
                  is_latest: true,
              },
          });
      }

      if (latest && !latest.is_draft && latest.attempt_no >= maxAttempts) {
          if (maxAttempts === 1) {
              await prisma.assignmentFeedback.updateMany({
                  where: { assignment_submission_id: latest.id, is_latest: true },
                  data: { is_latest: false },
              });

              const merged = this.mergeSubmissionPayload(payload, latest);
              return prisma.assignmentSubmission.update({
                  where: { id: latest.id },
                  data: {
                      ...merged,
                      status: 'in_progress',
                      draft_saved_at: now,
                      submitted_at: null,
                      reviewed_at: null,
                      reviewed_by_id: null,
                      marks_obtained: null,
                      remarks: null,
                      is_draft: true,
                      is_late: false,
                      is_latest: true,
                  },
              });
          }

          throw new ApiError('Maximum attempts reached. Draft cannot be created.', 400, 'MAX_ATTEMPTS_REACHED');
      }

      await prisma.assignmentSubmission.updateMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          data: { is_latest: false },
      });

      const merged = this.mergeSubmissionPayload(payload, latest);
      const nextAttemptNo = latest ? Number(latest.attempt_no) + 1 : 1;

      return prisma.assignmentSubmission.create({
          data: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              attempt_no: nextAttemptNo,
              ...merged,
              status: 'in_progress',
              draft_saved_at: now,
              submitted_at: null,
              is_draft: true,
              is_late: false,
              is_latest: true,
          },
      });
  }

  async submitAssignment(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      const assignment = await prisma.assignment.findFirst({
          where: { id: assignmentId, institute_id: instituteId },
          select: {
              id: true,
              due_date: true,
              allow_late_submission: true,
              late_grace_minutes: true,
              max_attempts: true,
              allow_text_submission: true,
              allow_file_submission: true,
              max_file_size_kb: true,
              allowed_file_types: true,
          },
      });

      if (!assignment) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      this.ensureSubmissionFileRules(assignment, data);

      const dueDate = assignment.due_date ? new Date(assignment.due_date as any) : null;
      const isLateNow = this.isLate(dueDate, Number(assignment.late_grace_minutes ?? 0));
      if (isLateNow && assignment.allow_late_submission === false) {
          throw new ApiError('Submission is after deadline and late submissions are disabled', 400, 'DEADLINE_PASSED');
      }

      const maxAttempts = Math.max(1, Number(assignment.max_attempts ?? 1));
      const now = new Date();
      const latest = await prisma.assignmentSubmission.findFirst({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          orderBy: { attempt_no: 'desc' },
      });

      const submittedAttempts = await prisma.assignmentSubmission.count({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_draft: false,
          },
      });

      if (latest?.is_draft) {
          if (latest.attempt_no > maxAttempts) {
              throw new ApiError('Maximum attempts reached', 400, 'MAX_ATTEMPTS_REACHED');
          }

          const merged = this.mergeSubmissionPayload(data, latest);
          return prisma.assignmentSubmission.update({
              where: { id: latest.id },
              data: {
                  ...merged,
                  status: isLateNow ? 'late_submission' : 'submitted',
                  submitted_at: now,
                  draft_saved_at: now,
                  reviewed_at: null,
                  reviewed_by_id: null,
                  marks_obtained: null,
                  remarks: null,
                  is_draft: false,
                  is_late: isLateNow,
                  is_latest: true,
              },
          });
      }

      if (submittedAttempts >= maxAttempts) {
          if (maxAttempts === 1 && latest && !isLateNow) {
              await prisma.assignmentFeedback.updateMany({
                  where: { assignment_submission_id: latest.id, is_latest: true },
                  data: { is_latest: false },
              });

              const merged = this.mergeSubmissionPayload(data, latest);
              return prisma.assignmentSubmission.update({
                  where: { id: latest.id },
                  data: {
                      ...merged,
                      status: 'submitted',
                      submitted_at: now,
                      draft_saved_at: now,
                      reviewed_at: null,
                      reviewed_by_id: null,
                      marks_obtained: null,
                      remarks: null,
                      is_draft: false,
                      is_late: false,
                      is_latest: true,
                  },
              });
          }

          throw new ApiError('Maximum attempts reached for this assignment', 400, 'MAX_ATTEMPTS_REACHED');
      }

      await prisma.assignmentSubmission.updateMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          data: { is_latest: false },
      });

      const merged = this.mergeSubmissionPayload(data, latest);
      const nextAttemptNo = latest ? Number(latest.attempt_no) + 1 : 1;

      return prisma.assignmentSubmission.create({
          data: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              attempt_no: nextAttemptNo,
              ...merged,
              status: isLateNow ? 'late_submission' : 'submitted',
              submitted_at: now,
              draft_saved_at: now,
              is_draft: false,
              is_late: isLateNow,
              is_latest: true,
          },
      });
  }

  async listAssignmentSubmissions(instituteId: string, assignmentId: string) {
      const items = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              is_latest: true,
              is_draft: false,
          },
          include: {
              student: { select: { id: true, name: true, photo_url: true } },
              assignment: {
                select: {
                  id: true,
                  title: true,
                  due_date: true,
                  max_marks: true,
                  batch_id: true,
                  subject: true,
                },
              },
              reviewed_by: { select: { id: true, role: true } },
              feedbacks: {
                  where: { is_latest: true },
                  orderBy: { revision_no: 'desc' },
                  take: 1,
              },
          },
          orderBy: [{ status: 'asc' }, { submitted_at: 'desc' }],
      });

      return items.map((item: any) => ({
          ...item,
          feedback: Array.isArray(item.feedbacks) && item.feedbacks.length > 0 ? item.feedbacks[0] : null,
      }));
  }

  async listMyAssignmentSubmissions(instituteId: string, assignmentId: string, studentId: string) {
      const items = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
          },
          include: {
              feedbacks: {
                  where: { is_latest: true },
                  orderBy: { revision_no: 'desc' },
                  take: 1,
              },
          },
          orderBy: [{ attempt_no: 'desc' }, { draft_saved_at: 'desc' }],
      });

      return items.map((item: any) => ({
          ...item,
          feedback: Array.isArray(item.feedbacks) && item.feedbacks.length > 0 ? item.feedbacks[0] : null,
      }));
  }

  async getAssignmentSubmissionFeedback(instituteId: string, submissionId: string) {
      return prisma.assignmentFeedback.findMany({
          where: {
              institute_id: instituteId,
              assignment_submission_id: submissionId,
          },
          orderBy: { revision_no: 'desc' },
      });
  }

  async reviewAssignmentSubmission(instituteId: string, submissionId: string, reviewerUserId: string, data: ReviewAssignmentSubmissionInput) {
      const submission = await prisma.assignmentSubmission.findFirst({
          where: { id: submissionId, institute_id: instituteId },
          include: {
              student: { select: { id: true, name: true } },
              assignment: {
                select: {
                  id: true,
                  title: true,
                  max_marks: true,
                },
              },
          },
      });

      if (!submission) {
          throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
      }

      if (submission.is_draft) {
          throw new ApiError('Draft cannot be evaluated before submission', 400, 'INVALID_REVIEW_STATE');
      }

      const maxMarks = submission.assignment?.max_marks != null ? Number(submission.assignment.max_marks) : null;
      if (data.marks_obtained != null && maxMarks != null && data.marks_obtained > maxMarks) {
          throw new ApiError(`Marks cannot exceed assignment max marks (${maxMarks})`, 400, 'INVALID_MARKS');
      }

      const latestFeedback = await prisma.assignmentFeedback.findFirst({
          where: { assignment_submission_id: submissionId, is_latest: true },
          orderBy: { revision_no: 'desc' },
      });

      if (latestFeedback) {
          await prisma.assignmentFeedback.updateMany({
              where: { assignment_submission_id: submissionId, is_latest: true },
              data: { is_latest: false },
          });
      }

      const feedbackText = this.trimOrNull((data as any).feedback_text) ?? this.trimOrNull(data.remarks);
      const nextMarks = data.marks_obtained
        ?? (latestFeedback?.marks_obtained != null ? Number(latestFeedback.marks_obtained) : this.toNumberOrNull(submission.marks_obtained));

      const feedback = await prisma.assignmentFeedback.create({
          data: {
              assignment_id: submission.assignment_id,
              assignment_submission_id: submission.id,
              institute_id: instituteId,
              student_id: submission.student_id,
              reviewer_user_id: reviewerUserId,
              marks_obtained: nextMarks,
              feedback_text: feedbackText,
              feedback_audio_url: this.trimOrNull((data as any).feedback_audio_url),
              annotated_file_url: this.trimOrNull((data as any).annotated_file_url),
              rubric_json: (data as any).rubric_json ?? null,
              revision_no: (latestFeedback?.revision_no ?? 0) + 1,
              is_latest: true,
          },
      });

      const reviewed = await prisma.assignmentSubmission.update({
          where: { id: submissionId, institute_id: instituteId },
          data: {
              status: data.status ?? 'evaluated',
              marks_obtained: nextMarks,
              remarks: feedbackText,
              reviewed_at: new Date(),
              reviewed_by_id: reviewerUserId,
              is_draft: false,
          },
          include: {
              student: { select: { id: true, name: true } },
              assignment: { select: { id: true, title: true, max_marks: true } },
              reviewed_by: { select: { id: true, role: true } },
          },
      });

      return { ...reviewed, feedback };
  }

  async getAssignmentAnalytics(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      const assignments = await prisma.assignment.findMany({
          where: {
              institute_id: instituteId,
              ...(filter.batchId && { batch_id: filter.batchId }),
              ...(filter.teacherId && { teacher_id: filter.teacherId }),
              ...(filter.subject && { subject: filter.subject }),
          },
          select: {
              id: true,
              title: true,
              batch_id: true,
              due_date: true,
              max_marks: true,
          },
      });

      if (assignments.length === 0) {
          return {
              assignments_count: 0,
              average_marks: 0,
              submission_rate: 0,
              late_submissions: 0,
              evaluated_submissions: 0,
              pending_evaluation: 0,
              by_assignment: [],
          };
      }

      const assignmentIds = assignments.map((a) => a.id);
      const latestSubmissions = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: { in: assignmentIds },
              is_latest: true,
              is_draft: false,
          },
          select: {
              assignment_id: true,
              status: true,
              is_late: true,
              marks_obtained: true,
              student_id: true,
          },
      });

      const batchIds = Array.from(new Set(assignments.map((a) => a.batch_id).filter(Boolean)));
      const activeBatchStudents = await prisma.studentBatch.findMany({
          where: {
              batch_id: { in: batchIds },
              is_active: true,
          },
          select: {
              batch_id: true,
              student_id: true,
          },
      });

      const enrollmentByBatch = new Map<string, number>();
      for (const item of activeBatchStudents) {
          enrollmentByBatch.set(item.batch_id, (enrollmentByBatch.get(item.batch_id) ?? 0) + 1);
      }

      const marks = latestSubmissions
        .map((item) => this.toNumberOrNull(item.marks_obtained))
        .filter((value): value is number => value !== null);

      const lateSubmissions = latestSubmissions.filter((item) => item.is_late || item.status === 'late_submission').length;
      const evaluated = latestSubmissions.filter((item) => item.status === 'evaluated').length;
      const pending = latestSubmissions.filter((item) => item.status === 'submitted' || item.status === 'late_submission').length;

      const byAssignment = assignments.map((assignment) => {
          const assignmentSubs = latestSubmissions.filter((item) => item.assignment_id === assignment.id);
          const enrolled = Math.max(1, enrollmentByBatch.get(assignment.batch_id) ?? 0);
          const submissionRate = (assignmentSubs.length / enrolled) * 100;

          return {
              assignment_id: assignment.id,
              title: assignment.title,
              batch_id: assignment.batch_id,
              submissions_count: assignmentSubs.length,
              enrolled_students: enrolled,
              submission_rate: Number(submissionRate.toFixed(2)),
              late_submissions: assignmentSubs.filter((item) => item.is_late || item.status === 'late_submission').length,
              evaluated_submissions: assignmentSubs.filter((item) => item.status === 'evaluated').length,
          };
      });

      const avgSubmissionRate = byAssignment.reduce((sum, item) => sum + item.submission_rate, 0) / byAssignment.length;
      const avgMarks = marks.length > 0 ? marks.reduce((sum, value) => sum + value, 0) / marks.length : 0;

      return {
          assignments_count: assignments.length,
          average_marks: Number(avgMarks.toFixed(2)),
          submission_rate: Number(avgSubmissionRate.toFixed(2)),
          late_submissions: lateSubmissions,
          evaluated_submissions: evaluated,
          pending_evaluation: pending,
          by_assignment: byAssignment,
      };
  }

  // DOUBTS
  async createDoubt(instituteId: string, studentId: string, data: CreateDoubtInput) {
      return prisma.doubt.create({
          data: { ...data, institute_id: instituteId, student_id: studentId }
      });
  }

  async respondToDoubt(doubtId: string, instituteId: string, teacherId: string, data: RespondDoubtInput) {
      return prisma.doubt.update({
          where: { id: doubtId, institute_id: instituteId },
          data: {
              ...data,
              assigned_to_id: teacherId,
              ...(data.status === 'resolved' && { resolved_at: new Date() })
          }
      });
  }

  async listDoubts(instituteId: string, filters: { batch_id?: string, student_id?: string, status?: string, subject?: string }) {
      try {
          return await prisma.doubt.findMany({
              where: { 
                institute_id: instituteId, 
                ...filters 
              },
              include: {
                  student: { select: { name: true } },
                  assigned_to: { select: { name: true } }
              },
              orderBy: { created_at: 'desc' }
          });
      } catch (error) {
          if (!this.isLegacyError(error, 'subject')) throw error;
          return this.listDoubtsLegacy(instituteId, filters);
      }
  }

  private async listDoubtsLegacy(instituteId: string, filters: { batch_id?: string, student_id?: string, status?: string, subject?: string }) {
    const batchIdParam = filters.batch_id ?? null;
    const studentIdParam = filters.student_id ?? null;
    const statusParam = filters.status ?? null;
    const rows = await prisma.$queryRaw<any[]>(Prisma.sql`
       SELECT d.id::text,
           d.title,
           d.description,
           d.status,
           d.created_at,
           d.student_id::text,
           s.name as student_name
       FROM doubts d
       LEFT JOIN students s ON d.student_id = s.id
       WHERE d.institute_id::text = ${instituteId}::text
         AND (${batchIdParam}::text IS NULL OR d.batch_id::text = ${batchIdParam}::text)
         AND (${studentIdParam}::text IS NULL OR d.student_id::text = ${studentIdParam}::text)
         AND (${statusParam}::text IS NULL OR d.status = ${statusParam}::text)
      `);
      return rows.map(r => ({
          ...r,
          student: { name: r.student_name },
          assigned_to: null
      }));
  }
}
