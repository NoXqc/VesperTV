import entries from './guide.json' with { type: 'json' };
import { handleRequest } from './interactions.mjs';

export default { fetch: (request, env) => handleRequest(request, env, entries) };
