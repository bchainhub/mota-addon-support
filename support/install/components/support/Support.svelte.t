---
to: src/lib/components/support/Support.svelte
---
<script lang="ts">
	import { z } from 'zod';
	import ICAN from '@blockchainhub/ican';
	import { Send, Sparkles } from 'lucide-svelte';
	import { ListBox } from '$components';
	import { LL } from '$lib/helpers/i18n';
	import { getSiteConfig } from '$lib/helpers/siteConfig';

	const __cfg = getSiteConfig();

	/** Module configs are flexible; assert the shape we need for support (ai, email, requireCoreId). */
	type SupportConfig = {
		enabled?: boolean;
		requireCoreId?: boolean;
		ai?: { enabled?: boolean; subjects?: string[] };
		email?: string;
	};
	const supportConfig = (__cfg?.modules as { support?: SupportConfig } | undefined)?.support;
	/** When true, Core ID is required and the field is shown. When false (default), Core ID field is hidden. */
	const requireCoreId = supportConfig?.requireCoreId === true;

	// --- Props ---
	type SupportMode = 'ai' | 'ticket';
	export let mode: SupportMode = 'ai';

	// --- Form state ---
	let coreId = '';
	// Initialize selectedSubject from config, will be set properly in reactive statement
	let selectedSubject: string = '';
	let question = '';
	let aiResponse: string | null = null;
	let loading = false;
	let error: string | null = null;

	// Check if AI is enabled
	const aiEnabled = supportConfig?.ai?.enabled ?? false;

	// --- Helpers ---
	const coreIdSchema = z
		.string()
		.trim()
		.min(1) // non-empty after trim
		.refine((value) => {
			try {
				return ICAN.isValid(value, true);
			} catch {
				return false;
			}
		}, { message: '' }); // message supplied reactively below

	// --- Reactive i18n-driven data ---
	// Subject options must update when locale changes
	// Get subjects from config, fallback to default list
	$: subjectsFromConfig = supportConfig?.ai?.subjects || ['general'];
	// Initialize selectedSubject to first subject from config if empty
	$: if (!selectedSubject && subjectsFromConfig.length > 0) {
		selectedSubject = subjectsFromConfig[0];
	}
	$: subjectOptions = subjectsFromConfig.map((subject: string) => {
		// Dynamically access LL.support.subject[subject]()
		const subjectTranslator = ($LL.modules.support.subjects as Record<string, () => string>)[subject];
		return {
			value: subject,
			label: subjectTranslator ? subjectTranslator() : subject
		};
	});

	// Mode options
	$: modeOptions = [
		{ value: 'ai', label: $LL.modules.support.askAI() ?? 'Ask AI' },
		{ value: 'ticket', label: $LL.modules.support.createTicket() ?? 'Create Ticket' }
	];

	// --- Validation state (compute once per change) ---
	$: trimmed = coreId.trim();
	$: parseResult = trimmed === '' ? null : coreIdSchema.safeParse(trimmed);
	// Valid when empty (so the field doesn't show red while typing), or when schema passes
	$: coreIdValid = trimmed === '' || (parseResult?.success ?? false);
	// Localized error message when invalid and non-empty
	$: coreIdErrorMessage = trimmed === '' || coreIdValid ? '' : $LL.modules.support.errors.coreIdError() ?? 'Please enter a valid Core ID';

	$: isFormValid = requireCoreId ? (trimmed !== '' && coreIdValid) : true;
	$: isAIFormValid = requireCoreId ? (isFormValid && question.trim() !== '') : question.trim() !== '';

	// Update mode and reset state
	function setMode(newMode: SupportMode) {
		mode = newMode;
		aiResponse = null;
		error = null;
		if (newMode === 'ai') {
			question = '';
		}
	}

	// Sync mode based on AI availability
	$: {
		if (!aiEnabled && mode === 'ai') {
			mode = 'ticket';
		}
	}

	// --- Mailto link (only when support email is configured and form valid) ---
	$: supportEmail = supportConfig?.email?.trim() ?? '';
	$: hasSupportEmail = supportEmail.length > 0;
	$: selectedSubjectLabel =
		subjectOptions.find((o: { value: string; label: string }) => o.value === selectedSubject)?.label ?? '';
	$: mailtoSubject =
		requireCoreId && trimmed !== '' ? `${selectedSubjectLabel} [${trimmed}]` : selectedSubjectLabel;
	$: mailtoLink = isFormValid && hasSupportEmail
		? `mailto:${supportEmail}?subject=${encodeURIComponent(mailtoSubject)}`
		: '#';

	async function handleSubmit() {
		if (mode === 'ai') {
			if (!question.trim()) {
				error = $LL.modules.support.errors.pleaseEnterYourQuestion() || 'Please enter your question';
				return;
			}
			await askAI();
		} else {
			sendTicket();
		}
	}

	async function askAI() {
		if (!aiEnabled) {
			error = $LL.modules.support.errors.aiServiceNotAvailable() || 'AI service is not available';
			return;
		}

		if (requireCoreId) {
			if (!(trimmed !== '' && coreIdValid)) {
				error = $LL.modules.support.errors.coreIdError() || 'Please enter a valid Core ID';
				return;
			}
		} else if (trimmed !== '' && !coreIdValid) {
			error = $LL.modules.support.errors.coreIdError() || 'Please enter a valid Core ID';
			return;
		}

		loading = true;
		error = null;

		try {
			const response = await fetch('/api/v1/support/ai', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					subject: selectedSubject,
					question: question.trim(),
					coreId: trimmed
				})
			});

			if (!response.ok) {
				const errorData = await response.json().catch(() => ({}));
				error = errorData.message || `Error: ${response.status} ${response.statusText}`;
				return;
			}

			const result = await response.json();

			if (result.status === 'success') {
				aiResponse = result.data.answer;
				question = ''; // Clear textarea after successful execution
			} else {
				error = result.message || $LL.modules.support.errors.failedToGetAIResponse() || 'Failed to get AI response';
			}
		} catch (err) {
			error = err instanceof Error ? err.message : $LL.modules.support.errors.anErrorOccurredWhileAskingAI() || 'An error occurred while asking AI';
		} finally {
			loading = false;
		}
	}

	function sendTicket() {
		window.location.href = mailtoLink;
	}
</script>

<section id="support" class="w-full py-16 md:py-8 lg:py-16">
	<div class="w-full">
		<div class="w-full mx-auto">
			<!-- Heading Section -->
			<div class="mb-12 heading-component w-full flex flex-col items-center">
				<div class="text-slate-900 dark:text-white font-bold tracking-tight w-full text-center text-2xl lg:text-3xl xl:text-4xl leading-tight max-xl:text-2xl max-xl:leading-tight max-md:text-xl max-md:leading-tight max-sm:text-xl max-sm:leading-tight">
					{$LL.modules.support.title() || 'Support'}
				</div>
			</div>

			<!-- Support Form -->
			<div class="max-w-4xl mx-auto">
				<div class="space-y-6">
					<!-- Mode Selection (only show if AI is enabled) -->
					{#if aiEnabled}
						<div class="relative my-6">
							<ListBox
								id="mode-select"
								items={modeOptions}
								value={mode}
								onChange={(value) => setMode(value as SupportMode)}
								className="text-lg"
							/>
						</div>
					{/if}

					<!-- Subject Dropdown -->
					<div class="relative my-6">
						<ListBox
							id="subject-select"
							items={subjectOptions}
							value={selectedSubject}
							onChange={(value) => (selectedSubject = value as string)}
							className="text-lg"
						/>
					</div>

					<!-- Core ID Field (only when requireCoreId is true) -->
					{#if requireCoreId}
						<div class="relative my-6">
							<input
								id="support-core-id"
								bind:value={coreId}
								type="text"
								placeholder={$LL.modules.support.coreId() || 'Core ID'}
								class="relative w-full h-12 px-4 placeholder-transparent transition-all border rounded outline-none focus-visible:outline-none peer text-slate-500 dark:text-slate-300 autofill:bg-white dark:autofill:bg-slate-800 focus:outline-none disabled:cursor-not-allowed disabled:bg-slate-50 dark:disabled:bg-slate-700 disabled:text-slate-400 dark:bg-slate-800
									{!coreIdValid && trimmed !== '' ? 'border-red-500' : coreIdValid && trimmed !== '' ? 'border-lime-500' : 'border-slate-200 dark:border-slate-600'}"
								required
							/>
							<label for="support-core-id" class="cursor-text peer-focus:cursor-default peer-autofill:-top-2 absolute left-2 -top-2 z-[1] px-2 text-xs text-slate-400 dark:text-slate-500 transition-all before:absolute before:top-0 before:left-0 before:z-[-1] before:block before:h-full before:w-full before:bg-white dark:before:bg-slate-800 before:transition-all peer-placeholder-shown:top-3 peer-placeholder-shown:text-base peer-focus:-top-2 peer-focus:text-xs peer-focus:text-indigo-500 peer-disabled:cursor-not-allowed peer-disabled:text-slate-400 peer-disabled:before:bg-transparent max-w-[calc(100%-1rem)] truncate overflow-hidden whitespace-nowrap">
								{$LL.modules.support.coreId() || 'Core ID'}
							</label>
							{#if coreIdErrorMessage}
								<p class="text-red-500 text-sm mt-1">{coreIdErrorMessage}</p>
							{/if}
						</div>
					{/if}

					<!-- AI Response (shown above textarea if available) -->
					{#if mode === 'ai' && aiResponse}
						<div class="bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-700 rounded-lg p-4">
							<div class="flex items-start gap-3">
								<Sparkles class="w-5 h-5 text-indigo-600 dark:text-indigo-400 flex-shrink-0 mt-0.5" />
								<div class="flex-1">
									<h3 class="text-sm font-semibold text-indigo-900 dark:text-indigo-100 mb-2">{$LL.modules.support.aiResponse() || 'AI Response'}</h3>
									<p class="text-sm text-indigo-800 dark:text-indigo-200 leading-relaxed whitespace-pre-wrap">
										{aiResponse}
									</p>
								</div>
							</div>
						</div>
					{/if}

					<!-- Question Textarea (only for AI mode) -->
					{#if mode === 'ai'}
						<div class="relative my-6">
							<textarea
								id="question"
								bind:value={question}
								rows="6"
								placeholder={aiResponse ? $LL.modules.support.followUpQuestion() || 'Follow-up Question' : $LL.modules.support.askYourQuestion() || 'Ask your question…'}
								class="relative w-full px-4 py-3 placeholder-transparent transition-all border rounded outline-none focus-visible:outline-none peer text-slate-500 dark:text-slate-300 autofill:bg-white dark:autofill:bg-slate-800 focus:outline-none disabled:cursor-not-allowed disabled:bg-slate-50 dark:disabled:bg-slate-700 disabled:text-slate-400 dark:bg-slate-800 resize-none border-slate-200 dark:border-slate-600 focus:border-indigo-500 dark:focus:border-indigo-400"
							></textarea>
							<label for="question" class="cursor-text peer-focus:cursor-default absolute left-2 -top-2 z-[1] px-2 text-xs text-slate-400 dark:text-slate-500 transition-all before:absolute before:top-0 before:left-0 before:z-[-1] before:block before:h-full before:w-full before:bg-white dark:before:bg-slate-800 before:transition-all peer-placeholder-shown:top-3 peer-placeholder-shown:text-base peer-focus:-top-2 peer-focus:text-xs peer-focus:text-indigo-500 peer-disabled:cursor-not-allowed peer-disabled:text-slate-400 peer-disabled:before:bg-transparent max-w-[calc(100%-1rem)] truncate overflow-hidden whitespace-nowrap">
								{aiResponse ? $LL.modules.support.followUpQuestion() || 'Follow-up Question' : $LL.modules.support.question() || 'Question'}
							</label>
						</div>
					{/if}

					<!-- Error Message -->
					{#if error}
						<div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
							<p class="text-sm text-red-800 dark:text-red-200">{error}</p>
						</div>
					{/if}

					<!-- Submit Button -->
					<div class="w-full">
						{#if mode === 'ai'}
							<button
								type="button"
								onclick={handleSubmit}
								disabled={loading || !isAIFormValid || !aiEnabled}
								class="w-full inline-flex items-center justify-center gap-2 px-8 py-3 font-semibold rounded-full transition-colors duration-300 bg-indigo-500 text-white hover:bg-indigo-600 active:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-300 dark:disabled:bg-slate-600 disabled:text-slate-500 dark:disabled:text-slate-400"
							>
								{#if loading}
									<span class="animate-spin">⏳</span>
									<span>{$LL.modules.support.processing() || 'Processing…'}</span>
								{:else}
									<Sparkles class="w-5 h-5" />
									<span>{$LL.modules.support.askAI() || 'Ask AI'}</span>
								{/if}
							</button>
						{:else}
							{#if isFormValid && hasSupportEmail}
								<a
									href={mailtoLink}
									class="w-full inline-flex items-center justify-center gap-2 px-8 py-3 font-semibold rounded-full transition-colors duration-300 bg-indigo-500 text-white! no-underline! hover:bg-indigo-600 cursor-pointer"
								>
									<Send class="w-5 h-5" />
									{$LL.modules.support.sendTicketByEmail() || 'Send Ticket by Email'}
								</a>
							{:else}
								<button
									disabled
									class="w-full inline-flex items-center justify-center gap-2 px-8 py-3 font-semibold rounded-full transition-colors duration-300 bg-slate-300 dark:bg-slate-600 text-slate-500 dark:text-slate-400 cursor-not-allowed"
								>
									<Send class="w-5 h-5" />
									{$LL.modules.support.sendTicketByEmail() || 'Send Ticket by Email'}
								</button>
							{/if}
						{/if}
					</div>
				</div>
			</div>
		</div>
	</div>
</section>
