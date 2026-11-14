import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-cashpilot-ai';
const backupPaths = [
  'accounts/account-1',
  'transactions/transaction-1',
  'categories/category-1',
  'payees/payee-1',
  'exchangeRates/rate-1',
  'budgets/budget-1',
  'goals/goal-1',
  'settings/main',
  'syncMetadata/device-1',
];

let environment;

before(async () => {
  const [host, portText] = (
    process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080'
  ).split(':');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host,
      port: Number(portText),
      rules: await readFile('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
});

after(async () => {
  await environment?.cleanup();
});

function databaseFor(userId, tokenOptions) {
  return environment.authenticatedContext(userId, tokenOptions).firestore();
}

describe('user-scoped backup collections', () => {
  for (const relativePath of backupPaths) {
    test(`owner can read and write users/{uid}/${relativePath}`, async () => {
      const database = databaseFor('alice');
      const reference = doc(database, `users/alice/${relativePath}`);
      await assertSucceeds(setDoc(reference, { owner: 'alice' }));
      const snapshot = await assertSucceeds(getDoc(reference));
      assert.equal(snapshot.data().owner, 'alice');
      await assertSucceeds(updateDoc(reference, { state: 'updated' }));
      await assertSucceeds(deleteDoc(reference));
    });

    test(`cross-user access is denied for ${relativePath}`, async () => {
      const database = databaseFor('alice');
      const reference = doc(database, `users/bob/${relativePath}`);
      await assertFails(setDoc(reference, { owner: 'alice' }));
      await assertFails(getDoc(reference));
      await assertFails(updateDoc(reference, { owner: 'alice' }));
      await assertFails(deleteDoc(reference));
    });

    test(`unauthenticated access is denied for ${relativePath}`, async () => {
      const database = environment.unauthenticatedContext().firestore();
      const reference = doc(database, `users/alice/${relativePath}`);
      await assertFails(setDoc(reference, { public: true }));
      await assertFails(getDoc(reference));
      await assertFails(updateDoc(reference, { public: true }));
      await assertFails(deleteDoc(reference));
    });

    test(`anonymous backup access is denied for ${relativePath}`, async () => {
      const database = databaseFor('guest', {
        firebase: { sign_in_provider: 'anonymous' },
      });
      const reference = doc(database, `users/guest/${relativePath}`);
      await assertFails(setDoc(reference, { guest: true }));
      await assertFails(getDoc(reference));
      await assertFails(updateDoc(reference, { guest: true }));
      await assertFails(deleteDoc(reference));
    });
  }
});

test('anonymous users can maintain only their root guest profile', async () => {
  const database = databaseFor('guest', {
    firebase: { sign_in_provider: 'anonymous' },
  });
  const ownProfile = doc(database, 'users/guest');
  const otherProfile = doc(database, 'users/alice');

  await assertSucceeds(setDoc(ownProfile, { isGuest: true }));
  await assertSucceeds(getDoc(ownProfile));
  await assertSucceeds(updateDoc(ownProfile, { state: 'deleting' }));
  await assertSucceeds(deleteDoc(ownProfile));
  await assertFails(setDoc(otherProfile, { isGuest: true }));
  await assertFails(getDoc(otherProfile));
  await assertFails(updateDoc(otherProfile, { state: 'tampered' }));
  await assertFails(deleteDoc(otherProfile));
});

test('public and invalid collection paths are denied', async () => {
  const authenticated = databaseFor('alice');
  const unauthenticated = environment.unauthenticatedContext().firestore();
  const paths = [
    'public/item-1',
    'accounts/account-1',
    'users/alice/unknown/item-1',
    'users/alice/settings/not-main',
    'users/alice/accounts/account-1/private/item-1',
  ];

  for (const path of paths) {
    await assertFails(setDoc(doc(authenticated, path), { invalid: true }));
    await assertFails(getDoc(doc(unauthenticated, path)));
  }
});

test('owner can update and delete the root profile', async () => {
  const owner = databaseFor('alice');
  const other = databaseFor('bob');
  const reference = doc(owner, 'users/alice');
  const crossUserReference = doc(other, 'users/alice');

  await assertSucceeds(setDoc(reference, { state: 'pending' }));
  await assertSucceeds(updateDoc(reference, { state: 'synced' }));
  await assertFails(updateDoc(crossUserReference, { state: 'tampered' }));
  await assertFails(deleteDoc(crossUserReference));
  await assertSucceeds(deleteDoc(reference));
});

test(
  'hard delete removes a seeded financial document without a tombstone',
  async () => {
    const sensitiveFields = {
      amount: '999.99',
      note: 'must-not-survive',
      accountId: 'private-account',
    };
    const path = 'users/alice/transactions/sensitive-transaction';
    const database = databaseFor('alice');
    const reference = doc(database, path);

    await assertSucceeds(setDoc(reference, sensitiveFields));
    assert.deepEqual(
      (await assertSucceeds(getDoc(reference))).data(),
      sensitiveFields,
    );
    await assertSucceeds(deleteDoc(reference));

    const afterDelete = await assertSucceeds(getDoc(reference));
    assert.equal(afterDelete.exists(), false);
    assert.equal(afterDelete.data(), undefined);
  },
);

test('tenant principals cannot access default-tenant data with the same uid', async () => {
  const defaultOwner = databaseFor('shared-uid');
  const rootPath = 'users/shared-uid';
  const accountPath = `${rootPath}/accounts/account-1`;
  await assertSucceeds(
    setDoc(doc(defaultOwner, rootPath), { tenant: 'default' }),
  );
  await assertSucceeds(
    setDoc(doc(defaultOwner, accountPath), { tenant: 'default' }),
  );

  // Firebase tenant identity is exposed as firebase.tenant. The top-level
  // tenant_id variant is also denied defensively for token-shape parity.
  const tenantTokenShapes = [
    {
      firebase: {
        sign_in_provider: 'password',
        tenant: 'tenant-a',
      },
    },
    {
      firebase: { sign_in_provider: 'password' },
      tenant_id: 'tenant-a',
    },
  ];
  for (const claims of tenantTokenShapes) {
    const tenant = databaseFor('shared-uid', claims);
    for (const path of [rootPath, accountPath]) {
      const reference = doc(tenant, path);
      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, { tenant: 'tenant-a' }));
      await assertFails(updateDoc(reference, { tenant: 'tenant-a' }));
      await assertFails(deleteDoc(reference));
    }
  }
});

test('a server deletion lock blocks every client write and is client-inaccessible', async () => {
  const owner = databaseFor('alice');
  const root = doc(owner, 'users/alice');
  await assertSucceeds(setDoc(root, { state: 'before-lock' }));
  for (const relativePath of backupPaths) {
    await assertSucceeds(
      setDoc(doc(owner, `users/alice/${relativePath}`), { state: 'before-lock' }),
    );
  }

  const lockId = createHash('sha256')
    .update('alice', 'utf8')
    .digest('hex')
    .toUpperCase();
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `accountDeletionLocks/${lockId}`), {
      operationId: 'opaque-operation',
      state: 'deleting',
    });
  });

  await assertFails(setDoc(root, { state: 'recreated' }));
  await assertFails(updateDoc(root, { state: 'updated' }));
  await assertFails(deleteDoc(root));
  for (const relativePath of backupPaths) {
    const existing = doc(owner, `users/alice/${relativePath}`);
    const created = doc(owner, `users/alice/${relativePath}-new`);
    await assertFails(setDoc(created, { state: 'created-after-lock' }));
    await assertFails(updateDoc(existing, { state: 'updated-after-lock' }));
    await assertFails(deleteDoc(existing));
  }

  const lock = doc(owner, `accountDeletionLocks/${lockId}`);
  await assertFails(getDoc(lock));
  await assertFails(setDoc(lock, { operationId: 'tampered' }));
  await assertFails(updateDoc(lock, { state: 'tampered' }));
  await assertFails(deleteDoc(lock));
});
