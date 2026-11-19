import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { createAccountDeletionHandler } from './account-deletion.mjs';

initializeApp();
export const deleteAccount = onRequest({
  region: process.env.HYNER_FUNCTION_REGION || 'asia-south1',
  timeoutSeconds: 120,
  maxInstances: 2,
  cors: false,
}, createAccountDeletionHandler({ auth: getAuth(), firestore: getFirestore() }));
