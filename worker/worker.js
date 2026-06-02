// Rate-limit store: IP → { count, reset }
const rateLimit = new Map();

function checkRateLimit(ip, limit, windowMs) {
  const now = Date.now();
  let record = rateLimit.get(ip);
  if (!record || now > record.reset) {
    record = { count: 0, reset: now + windowMs };
    rateLimit.set(ip, record);
  }
  record.count++;
  // Clean up expired entries periodically
  if (rateLimit.size > 10000) {
    for (const [k, v] of rateLimit) {
      if (now > v.reset) rateLimit.delete(k);
    }
  }
  return record.count <= limit;
}

function getClientIP(request) {
  return request.headers.get('CF-Connecting-IP') || 'unknown';
}

function json(data, status) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    // Only allow POST and GET
    if (request.method !== 'POST' && request.method !== 'GET') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const ip = getClientIP(request);

    // GET requests: 30 req / 10 min per IP (checking issue status, reading comments)
    if (request.method === 'GET') {
      if (!checkRateLimit(ip, 30, 600000)) {
        return json({ error: '请求太频繁，请稍后再试' }, 429);
      }

      const issueMatch = path.match(/^\/issues\/(\d+)$/);
      if (issueMatch) return handleGetIssue(issueMatch[1], env);

      const commentsMatch = path.match(/^\/issues\/(\d+)\/comments$/);
      if (commentsMatch) return handleGetComments(commentsMatch[1], env);

      return json({ error: 'Not found' }, 404);
    }

    // POST /issues: 3 req / hour per IP (creating issues)
    if (path === '/issues') {
      if (!checkRateLimit(ip, 3, 3600000)) {
        return json({ error: '提交太频繁，每小时最多 3 条反馈' }, 429);
      }

      // Content size limit: 10KB
      const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
      if (contentLength > 10240) {
        return json({ error: '内容过长，请精简描述' }, 413);
      }

      return handleCreateIssue(request, env);
    }

    return json({ error: 'Not found' }, 404);
  },
};

async function handleCreateIssue(request, env) {
  try {
    const body = await request.json();
    const { title, body: issueBody, labels } = body;

    // Validate required fields
    if (!title || !issueBody || typeof title !== 'string' || typeof issueBody !== 'string') {
      return json({ error: '标题和内容不能为空' }, 400);
    }
    if (title.length > 200) return json({ error: '标题不能超过 200 字' }, 400);
    if (issueBody.length > 5000) return json({ error: '内容不能超过 5000 字' }, 400);

    const ghResp = await fetch('https://api.github.com/repos/Shortcomings/bookkeeping/issues', {
      method: 'POST',
      headers: {
        'Authorization': `token ${env.GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
        'User-Agent': 'bookkeeping-feedback',
      },
      body: JSON.stringify({ title, body: issueBody, labels }),
    });
    const data = await ghResp.json();
    return json(data, ghResp.status);
  } catch (e) {
    return json({ error: e.message }, 500);
  }
}

async function handleGetIssue(number, env) {
  try {
    const ghResp = await fetch(`https://api.github.com/repos/Shortcomings/bookkeeping/issues/${number}`, {
      headers: {
        'Authorization': `token ${env.GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'bookkeeping-feedback',
      },
    });
    const data = await ghResp.json();
    return json(data, ghResp.status);
  } catch (e) {
    return json({ error: e.message }, 500);
  }
}

async function handleGetComments(number, env) {
  try {
    const ghResp = await fetch(`https://api.github.com/repos/Shortcomings/bookkeeping/issues/${number}/comments`, {
      headers: {
        'Authorization': `token ${env.GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'bookkeeping-feedback',
      },
    });
    const data = await ghResp.json();
    return json(data, ghResp.status);
  } catch (e) {
    return json({ error: e.message }, 500);
  }
}
