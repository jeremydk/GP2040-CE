import { useRef, useState } from 'react';
import { Button, Table, Alert } from 'react-bootstrap';
import { useTranslation } from 'react-i18next';

import WebApi from '../Services/WebApi';

// Empirically measures per-pin switch bounce by hitting the
// /api/runDebounceProbe endpoint. The endpoint blocks the device's
// webconfig loop for ~5 seconds while sampling GPIO; the user is
// expected to press each button once during that window. Results come
// back as { pins: { pinNN: { maxEnvelopeUs, transitions } } }.

const PHASE_IDLE = 'idle';
const PHASE_RUNNING = 'running';
const PHASE_RESULTS = 'results';
const PHASE_ERROR = 'error';

// Round bounce microseconds up to a sensible debounce value in ms.
// Add a 1 ms margin so the user isn't riding the edge of the envelope
// they just measured.
const suggestDebounceMs = (maxEnvelopeUs) => {
	const ms = Math.ceil(maxEnvelopeUs / 1000);
	return Math.max(1, ms + 1);
};

export default function DebounceProbe({ onApply }) {
	const { t } = useTranslation('');
	const [phase, setPhase] = useState(PHASE_IDLE);
	const [results, setResults] = useState(null);
	const [errorMsg, setErrorMsg] = useState('');
	const abortRef = useRef(null);

	const run = async () => {
		setPhase(PHASE_RUNNING);
		setResults(null);
		setErrorMsg('');
		abortRef.current = new AbortController();
		const data = await WebApi.runDebounceProbe(abortRef.current.signal);
		if (data?.canceled) {
			setPhase(PHASE_IDLE);
			return;
		}
		if (data?.error || !data?.pins) {
			setErrorMsg(data?.error || t('DebounceProbe:no-data'));
			setPhase(PHASE_ERROR);
			return;
		}
		setResults(data);
		setPhase(PHASE_RESULTS);
	};

	const worstBounceUs =
		results &&
		Math.max(
			0,
			...Object.values(results.pins || {}).map((p) => p.maxEnvelopeUs || 0),
		);
	const suggested = worstBounceUs ? suggestDebounceMs(worstBounceUs) : null;

	return (
		<div className="mb-3">
			<div className="mb-2">
				<strong>{t('DebounceProbe:header')}</strong>
				<div className="text-muted small">
					{t('DebounceProbe:instructions')}
				</div>
			</div>

			{phase === PHASE_IDLE && (
				<Button variant="outline-primary" size="sm" onClick={run}>
					{t('DebounceProbe:start')}
				</Button>
			)}

			{phase === PHASE_RUNNING && (
				<Alert variant="info" className="py-2 mb-0">
					{t('DebounceProbe:running')}
				</Alert>
			)}

			{phase === PHASE_ERROR && (
				<Alert variant="danger" className="py-2 mb-0">
					{errorMsg || t('DebounceProbe:no-data')}
					<div>
						<Button
							variant="outline-secondary"
							size="sm"
							className="mt-2"
							onClick={() => setPhase(PHASE_IDLE)}
						>
							{t('Common:button-dismiss-label')}
						</Button>
					</div>
				</Alert>
			)}

			{phase === PHASE_RESULTS && results && (
				<>
					{Object.keys(results.pins || {}).length === 0 ? (
						<Alert variant="warning" className="py-2">
							{t('DebounceProbe:no-presses')}
						</Alert>
					) : (
						<>
							<Table size="sm" bordered className="mb-2">
								<thead>
									<tr>
										<th>{t('DebounceProbe:col-pin')}</th>
										<th>{t('DebounceProbe:col-bounce')}</th>
										<th>{t('DebounceProbe:col-transitions')}</th>
									</tr>
								</thead>
								<tbody>
									{Object.entries(results.pins)
										.sort(([a], [b]) => a.localeCompare(b))
										.map(([pin, data]) => (
											<tr key={pin}>
												<td>{pin}</td>
												<td>
													{(data.maxEnvelopeUs / 1000).toFixed(2)} ms
												</td>
												<td>{data.transitions}</td>
											</tr>
										))}
								</tbody>
							</Table>
							<div className="mb-2">
								<strong>{t('DebounceProbe:suggested')}:</strong> {suggested} ms
								<span className="text-muted ms-2">
									({t('DebounceProbe:worst-bounce', {
										us: Math.round(worstBounceUs),
									})})
								</span>
							</div>
							<Button
								variant="outline-success"
								size="sm"
								className="me-2"
								onClick={() => {
									onApply?.(suggested);
									setPhase(PHASE_IDLE);
								}}
							>
								{t('DebounceProbe:apply', { ms: suggested })}
							</Button>
						</>
					)}
					<Button
						variant="outline-secondary"
						size="sm"
						onClick={() => setPhase(PHASE_IDLE)}
					>
						{t('DebounceProbe:reset')}
					</Button>
				</>
			)}
		</div>
	);
}
