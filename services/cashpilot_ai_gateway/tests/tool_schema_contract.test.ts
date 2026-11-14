import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";
import {
  serverToolAllowlist,
  toolSelectionJsonSchema,
  type ServerToolId,
} from "../src/tools/allowlist.js";

test("the complete governed tool provider schema remains byte-compatible", () => {
  const ids = Object.keys(serverToolAllowlist) as ServerToolId[];
  assert.equal(ids.length, 26);
  const providerSchema = JSON.stringify(toolSelectionJsonSchema(ids));
  assert.equal(providerSchema.length, 10_162);
  assert.equal(
    createHash("sha256").update(providerSchema).digest("hex"),
    "e582ee96aae19374f0613a2f58153a9e3f724b0d846998a45779fef47f48da77",
  );
});
