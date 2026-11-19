/** The bearer token determines the only account this endpoint may delete. */
export function createAccountDeletionHandler({ auth, firestore, now = Date.now }) {
  return async (request, response) => {
    response.set('Cache-Control', 'no-store');
    if (request.method !== 'POST') return response.status(405).json({ error: 'method-not-allowed' });
    if (request.body?.confirm !== 'DELETE_MY_ACCOUNT') return response.status(400).json({ error: 'confirmation-required' });
    const match = /^Bearer ([^\s]+)$/.exec(request.get('Authorization') ?? '');
    if (!match) return response.status(401).json({ error: 'sign-in-required' });
    let identity;
    try {
      identity = await auth.verifyIdToken(match[1]);
      const age = Math.floor(now() / 1000) - Number(identity.auth_time);
      if (!identity.uid || !Number.isFinite(age) || age < -60 || age > 300) {
        return response.status(401).json({ error: 'recent-sign-in-required' });
      }
    } catch {
      return response.status(401).json({ error: 'sign-in-required' });
    }
    try {
      // Includes legacy products and nested movement history, even if the
      // parent profile document no longer exists. No caller path is accepted.
      await firestore.recursiveDelete(firestore.collection('users').doc(identity.uid));
      try {
        await auth.deleteUser(identity.uid);
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
      }
      return response.status(200).json({ deleted: true, uid: identity.uid });
    } catch {
      // Do not log tokens, email, business rows or customer details.
      return response.status(503).json({ error: 'deletion-incomplete-retry' });
    }
  };
}
