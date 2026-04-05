import { createNoteSchema } from '../src/modules/content/content.validator';

describe('createNoteSchema file_type contract', () => {
  const baseBody = {
    title: 'Chapter Notes',
    batch_id: '00000000-0000-0000-0000-000000000101',
    file_url: 'https://cdn.example.com/notes/chapter-1.pdf',
  };

  it('rejects legacy file_type="note" payload', () => {
    const parsed = createNoteSchema.safeParse({
      body: {
        ...baseBody,
        file_type: 'note',
      },
    });

    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((issue) => issue.path.join('.') === 'body.file_type')).toBe(true);
    }
  });

  it('accepts valid enum file_type payloads', () => {
    const parsed = createNoteSchema.safeParse({
      body: {
        ...baseBody,
        file_type: 'image',
      },
    });

    expect(parsed.success).toBe(true);
  });
});
