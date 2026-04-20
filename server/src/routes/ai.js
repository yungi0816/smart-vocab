const fs = require('fs');
const path = require('path');
const { DATA_DIR } = require('../config');

const TOKEN_PATH =
  process.env.AI_TOKEN_PATH || path.join(DATA_DIR, 'ai_token.json');
const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID || '';
const AI_API_URL =
  process.env.AI_API_URL || 'https://models.inference.ai.azure.com';
const AI_MODEL = process.env.AI_MODEL || 'gpt-4.1';

let aiToken = process.env.AI_API_KEY || '';

function loadToken() {
  if (aiToken) return;
  try {
    if (fs.existsSync(TOKEN_PATH)) {
      const data = JSON.parse(fs.readFileSync(TOKEN_PATH, 'utf-8'));
      if (data.access_token) aiToken = data.access_token;
    }
  } catch {
    aiToken = '';
  }
}

function saveToken(tokenData) {
  aiToken = tokenData.access_token;
  fs.mkdirSync(path.dirname(TOKEN_PATH), { recursive: true });
  fs.writeFileSync(TOKEN_PATH, JSON.stringify(tokenData, null, 2), 'utf-8');
}

loadToken();

function normalizeUiLang(uiLang) {
  return uiLang === 'ja' ? 'ja' : 'ko';
}

function tutorSystemPrompt(uiLang) {
  if (normalizeUiLang(uiLang) === 'ja') {
    return [
      'You are a concise language study tutor for TOEIC, English, Japanese, and Korean vocabulary.',
      'Answer in Japanese.',
      'Focus on exam usage, memory hooks, and short examples.',
      'Keep the tone calm and practical.',
    ].join(' ');
  }

  return [
    'You are a concise TOEIC vocabulary tutor.',
    'Answer in Korean.',
    'Focus on exam usage, memory hooks, and short examples.',
    'Keep the tone calm and practical.',
  ].join(' ');
}

async function callAI(systemPrompt, userMessage, history = []) {
  if (!aiToken) return null;

  try {
    const res = await fetch(`${AI_API_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${aiToken}`,
      },
      body: JSON.stringify({
        model: AI_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          ...history,
          { role: 'user', content: userMessage },
        ],
        max_tokens: 500,
        temperature: 0.6,
      }),
    });

    if (!res.ok) return null;
    const data = await res.json();
    return data.choices?.[0]?.message?.content || null;
  } catch {
    return null;
  }
}

function offlineExplain({ word, meaning, correctAnswer, uiLang }) {
  if (normalizeUiLang(uiLang) === 'ja') {
    return `"${word}" means "${meaning}". The correct answer is "${correctAnswer}". Review the word with one short example sentence and check which clue in the meaning points to the answer.`;
  }

  return `"${word}"의 뜻은 "${meaning}"입니다. 정답은 "${correctAnswer}"이고, 헷갈린 선택지는 뜻의 핵심 단서와 다른 방향일 가능성이 큽니다. 짧은 예문 하나를 만들어 소리 내어 읽으면 다음 복습 때 더 빨리 떠올릴 수 있습니다.`;
}

function offlineExample({ word, meaning, uiLang }) {
  if (normalizeUiLang(uiLang) === 'ja') {
    return `Example: "Please ${word.toLowerCase()} the report before Friday."\nMeaning: ${meaning || 'Check the word meaning and rewrite the sentence in your own words.'}`;
  }

  return `Example: "Please ${word.toLowerCase()} the report before Friday."\n뜻: ${meaning || '단어 뜻을 확인한 뒤 직접 문장을 바꿔 써 보세요.'}`;
}

function offlineChat(message, uiLang) {
  if (normalizeUiLang(uiLang) === 'ja') {
    return `今はオフライン応答です。質問は受け取りました: "${message}"\n単語の意味、例文、復習方法の順で短く整理してみてください。`;
  }

  return `현재는 오프라인 응답입니다. 질문은 확인했습니다: "${message}"\n단어의 뜻, 예문, 복습 포인트 순서로 짧게 정리해 보세요.`;
}

module.exports = async function aiRoutes(fastify) {
  fastify.get('/api/ai/auth/status', async () => ({
    authenticated: !!aiToken,
    model: AI_MODEL,
  }));

  fastify.post('/api/ai/auth/start', async (request, reply) => {
    if (!GITHUB_CLIENT_ID) {
      return reply.status(400).send({
        error: 'GITHUB_CLIENT_ID is not configured.',
      });
    }

    try {
      const res = await fetch('https://github.com/login/device/code', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ client_id: GITHUB_CLIENT_ID, scope: '' }),
      });

      if (!res.ok) {
        const detail = await res.text().catch(() => '');
        return reply.status(502).send({
          error: 'GitHub device flow failed.',
          detail,
        });
      }

      return res.json();
    } catch (e) {
      return reply.status(500).send({ error: e.message });
    }
  });

  fastify.post('/api/ai/auth/poll', async (request, reply) => {
    const { device_code: deviceCode } = request.body || {};
    if (!deviceCode) {
      return reply.status(400).send({ error: 'Missing device_code.' });
    }
    if (!GITHUB_CLIENT_ID) {
      return reply.status(400).send({
        error: 'GITHUB_CLIENT_ID is not configured.',
      });
    }

    try {
      const res = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          client_id: GITHUB_CLIENT_ID,
          device_code: deviceCode,
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
        }),
      });

      if (!res.ok) {
        return reply.status(502).send({ error: 'GitHub token request failed.' });
      }

      const data = await res.json();
      if (data.access_token) {
        saveToken(data);
        return { success: true, authenticated: true };
      }
      return data;
    } catch (e) {
      return reply.status(500).send({ error: e.message });
    }
  });

  fastify.post('/api/ai/explain', async (request, reply) => {
    const {
      word,
      meaning,
      userAnswer,
      correctAnswer,
      uiLang,
    } = request.body || {};

    if (!word || !meaning) {
      return reply.status(400).send({ error: 'Missing word or meaning.' });
    }

    const system = tutorSystemPrompt(uiLang);
    const userMessage =
      normalizeUiLang(uiLang) === 'ja'
        ? `Explain why "${word}" means "${meaning}". The learner chose "${userAnswer}", but the correct answer was "${correctAnswer}". Keep it within 3 sentences.`
        : `"${word}"의 뜻은 "${meaning}"입니다. 학습자는 "${userAnswer}"를 골랐고 정답은 "${correctAnswer}"였습니다. 왜 정답인지 3문장 이내로 설명해 주세요.`;

    const aiReply = await callAI(system, userMessage);
    return {
      explanation:
        aiReply ||
        offlineExplain({ word, meaning, correctAnswer, uiLang }),
    };
  });

  fastify.post('/api/ai/example', async (request, reply) => {
    const { word, meaning, uiLang } = request.body || {};
    if (!word) return reply.status(400).send({ error: 'Missing word.' });

    const system = tutorSystemPrompt(uiLang);
    const userMessage =
      normalizeUiLang(uiLang) === 'ja'
        ? `Create two short example sentences for "${word}" (${meaning || 'unknown meaning'}).`
        : `"${word}" (${meaning || '뜻 미상'})를 활용한 짧은 예문 2개와 한국어 해석을 만들어 주세요.`;

    const aiReply = await callAI(system, userMessage);
    return {
      example: aiReply || offlineExample({ word, meaning, uiLang }),
    };
  });

  fastify.post('/api/ai/chat', async (request, reply) => {
    const { message, history, uiLang } = request.body || {};
    if (!message) return reply.status(400).send({ error: 'Missing message.' });

    const recentHistory = (history || [])
      .slice(-10)
      .map((item) => ({
        role: item.role === 'assistant' ? 'assistant' : 'user',
        content: String(item.content || ''),
      }))
      .filter((item) => item.content);

    const aiReply = await callAI(
      tutorSystemPrompt(uiLang),
      message,
      recentHistory,
    );

    return {
      reply: aiReply || offlineChat(message, uiLang),
    };
  });
};
