// ─── Async Handler (eliminates try-catch boilerplate) ─────────────────────────
exports.asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};
