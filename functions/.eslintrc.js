module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: ["eslint:recommended"],
  rules: {
    // Tắt các rule gây phiền toái
    indent: "off", // không check indent
    "comma-dangle": "off", // không bắt dấu phẩy cuối
    "object-curly-spacing": "off", // không bắt khoảng trắng trong object
    "max-len": "off", // cho phép dài quá 80 ký tự
    quotes: ["error", "double"], // ép dùng dấu nháy kép
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
};
