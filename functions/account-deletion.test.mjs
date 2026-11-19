import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccountDeletionHandler } from './account-deletion.mjs';

function fixture(overrides = {}) {
  const deleted = [];
  const auth = {
    verifyIdToken: async () => ({ uid: 'owner', auth_time: 1000 }),
    deleteUser: async uid => deleted.push(`auth:${uid}`),
    ...overrides,
  };
  const firestore = {
    collection: name => ({ doc: uid => `${name}/${uid}` }),
    recursiveDelete: async path => deleted.push(path),
  };
  const handler = createAccountDeletionHandler({ auth, firestore, now: () => 1100_000 });
  const request = { method: 'POST', body: { confirm: 'DELETE_MY_ACCOUNT', uid: 'victim' }, get: () => 'Bearer valid-token' };
  const response = { code: null, body: null, set() {}, status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
  return { handler, request, response, deleted };
}
test('deletes only the authenticated account including nested legacy data', async () => {
  const f = fixture(); await f.handler(f.request, f.response);
  assert.equal(f.response.code, 200); assert.deepEqual(f.deleted, ['users/owner', 'auth:owner']);
});
test('rejects absent, invalid and stale credentials before deleting any data', async () => {
  for (const override of [
    { verifyIdToken: async () => { throw Error('invalid'); } },
    { verifyIdToken: async () => ({ uid: 'owner', auth_time: 1 }) },
  ]) {
    const f = fixture(override); await f.handler(f.request, f.response);
    assert.equal(f.response.code, 401); assert.deepEqual(f.deleted, []);
  }
});
test('requires explicit confirmation and POST', async () => {
  const f = fixture(); f.request.body = {}; await f.handler(f.request, f.response);
  assert.equal(f.response.code, 400); assert.deepEqual(f.deleted, []);
  f.request.method = 'GET'; await f.handler(f.request, f.response); assert.equal(f.response.code, 405);
});
test('does not claim successful deletion when auth cleanup fails', async () => {
  const f = fixture({ deleteUser: async () => { throw Error('unavailable'); } });
  await f.handler(f.request, f.response); assert.equal(f.response.code, 503);
});
test('a retry after deletion remains idempotent with a valid recent token', async () => {
  const f = fixture({ deleteUser: async () => { throw Object.assign(Error('gone'), { code: 'auth/user-not-found' }); } });
  await f.handler(f.request, f.response); assert.equal(f.response.code, 200);
});
