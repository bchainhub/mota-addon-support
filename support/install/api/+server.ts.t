---
to: src/routes/api/[version]/support/ai/+server.ts
---
import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { handleOptions, withCorsHeaders } from '$lib/server/apiHandler';
import { ApiError } from '$lib/server/apiError';
import { env } from '$env/dynamic/private';
import ICAN from '@blockchainhub/ican';

import { getSiteConfig } from '$lib/helpers/siteConfig';

/** Module configs are flexible; assert the shape we need for support.ai. */
type SupportAiConfig = {
	enabled?: boolean;
	systemMessage?: string;
	model?: string;
	temperature?: number;
	maxTokens?: number;
};
type SupportConfig = { requireCoreId?: boolean; ai?: SupportAiConfig };

function getSupportConfig(): SupportConfig | undefined {
	return (getSiteConfig()?.modules as { support?: SupportConfig } | undefined)?.support;
}

function getSupportAi(): SupportAiConfig | undefined {
	return getSupportConfig()?.ai;
}

export const OPTIONS = handleOptions;

export const POST: RequestHandler = async ({ request, url }) => {
	const supportAi = getSupportAi();
	if (!supportAi?.enabled) {
		throw new ApiError('error', 403, 'Support AI service is not enabled');
	}
	try {
		// Check if AI is enabled
		if (!env.AI_API_KEY || !env.AI_API_URL) {
			throw new ApiError('error', 503, 'AI service is not configured');
		}

		// Verify request is from the same origin (protect against external usage)
		const origin = request.headers.get('origin');
		const referer = request.headers.get('referer');
		const allowedOrigin = getSiteConfig()?.url || url.origin;

		// Same-origin requests don't send Origin header, so null is valid
		// Cross-origin requests must have matching origin or referer
		if (origin !== null) {
			try {
				const originUrl = new URL(origin);
				const allowedUrl = new URL(allowedOrigin);
				if (originUrl.origin !== allowedUrl.origin) {
					// Check referer as fallback
					if (referer) {
						try {
							const refererUrl = new URL(referer);
							if (refererUrl.origin !== allowedUrl.origin) {
								throw new ApiError('error', 403, 'Forbidden: Request must come from the website');
							}
						} catch {
							throw new ApiError('error', 403, 'Forbidden: Request must come from the website');
						}
					} else {
						throw new ApiError('error', 403, 'Forbidden: Request must come from the website');
					}
				}
			} catch (err) {
				if (err instanceof ApiError) {
					throw err;
				}
				throw new ApiError('error', 403, 'Forbidden: Invalid origin');
			}
		}

		const body = await request.json();
		const { subject, question, coreId } = body;
		const supportConfig = getSupportConfig();
		const requireCoreId = supportConfig?.requireCoreId === true;

		if (requireCoreId) {
			if (!coreId) {
				throw new ApiError('error', 400, 'Core ID is required');
			}
			if (!ICAN.isValid(coreId, 'mainnet')) {
				throw new ApiError('error', 400, 'Invalid Core ID');
			}
		} else if (coreId != null && coreId !== '' && !ICAN.isValid(coreId, 'mainnet')) {
			throw new ApiError('error', 400, 'Invalid Core ID');
		}

		if (!subject || !question || typeof subject !== 'string' || typeof question !== 'string') {
			throw new ApiError('error', 400, 'Subject and question are required');
		}

		// Get system message from env or use default
		const defaultSystemMessage = 'You are a helpful support assistant. Provide clear, accurate, and helpful answers.';
		const systemParts = [supportAi.systemMessage || defaultSystemMessage, `Current support subject: ${subject}`];
		if (coreId && typeof coreId === 'string' && coreId.trim() !== '') {
			systemParts.splice(1, 0, `Customer Core ID: ${coreId.trim()}`);
		}
		const systemMessage = systemParts.join('\n\n');

		// Call AI API
		const aiResponse = await fetch(env.AI_API_URL, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${env.AI_API_KEY}`
			},
			body: JSON.stringify({
				model: supportAi.model || 'gpt-4o-mini',
				messages: [
					{
						role: 'system',
						content: systemMessage
					},
					{
						role: 'user',
						content: question
					}
				],
				temperature: supportAi.temperature ?? 0.4,
				max_tokens: supportAi.maxTokens ?? 150
			})
		});

		if (!aiResponse.ok) {
			const errorData = await aiResponse.json().catch(() => ({}));
			throw new ApiError('error', aiResponse.status, `AI API error: ${errorData.error?.message || aiResponse.statusText}`);
		}

		const aiData = await aiResponse.json();
		const answer = aiData.choices?.[0]?.message?.content || 'No response from AI';

		const response = {
			status: 'success',
			data: {
				answer,
				subject,
				question
			}
		};

		return withCorsHeaders(json(response));
	} catch (error) {
		if (error instanceof ApiError) {
			throw error;
		}
		throw new ApiError('error', 500, 'Internal server error');
	}
};
