import { z } from "zod";

export const ToolSelectionSchema = z
  .object({
    name: z.string().regex(/^[a-z][a-z0-9_]{1,63}$/),
    arguments: z.record(z.string(), z.unknown()),
  })
  .strict();

export const ToolSelectionResponseSchema = z
  .object({
    toolSelections: z.array(ToolSelectionSchema).max(3),
    clarification: z.string().trim().max(300).nullable(),
  })
  .strict();
export type ToolSelectionResponse = z.infer<
  typeof ToolSelectionResponseSchema
>;
