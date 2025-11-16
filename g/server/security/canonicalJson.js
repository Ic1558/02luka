const isPlainObject = (value) => {
  return Object.prototype.toString.call(value) === "[object Object]";
};

function canonicalize(value) {
  if (Array.isArray(value)) {
    return value.map((item) => canonicalize(item));
  }
  if (isPlainObject(value)) {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      const canonicalValue = canonicalize(value[key]);
      if (canonicalValue === undefined) {
        continue;
      }
      result[key] = canonicalValue;
    }
    return result;
  }
  return value;
}

function canonicalJsonStringify(value, space = 2) {
  return JSON.stringify(canonicalize(value), null, space);
}

module.exports = { canonicalJsonStringify };
