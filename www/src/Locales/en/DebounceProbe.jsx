export default {
	header: 'Measure switch bounce',
	instructions:
		'Starts a 5-second probe during which you should press each button once (and release). The device will report the worst bounce observed per pin and suggest a safe Debounce Delay.',
	start: 'Start 5-second probe',
	running: 'Probing — press each button once, then release. Please wait ~5 seconds…',
	'no-presses':
		'No button transitions observed during the probe window. Did you press any buttons?',
	'no-data': 'The probe returned no data.',
	'col-pin': 'Pin',
	'col-bounce': 'Worst bounce',
	'col-transitions': 'Transitions',
	suggested: 'Suggested Debounce Delay',
	'worst-bounce': 'worst observed: {{us}} µs',
	apply: 'Apply {{ms}} ms',
	reset: 'Dismiss',
};
