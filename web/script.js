const env = {
	memory: new WebAssembly.Memory({initial: 1}),
	__stack_pointer: 0,
};

var zjb = new Zjb();

(function() {
	WebAssembly.instantiateStreaming(fetch("example.wasm"), {env: env, zjb: zjb.imports}).then(function (results) {
		zjb.setInstance(results.instance);
		results.instance.exports.main();
	});
})();
