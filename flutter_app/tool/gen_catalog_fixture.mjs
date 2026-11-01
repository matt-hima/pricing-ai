// 把編輯器的動作目錄存成測試用的夾具（Dart 測試用它檢查提示詞與解析）。
// 動作目錄改了就重新執行：node tool/gen_catalog_fixture.mjs
import { ACTIONS } from "../assets/editor/actions.js";
import { writeFileSync } from "node:fs";

const catalog = ACTIONS.map(({ name, description, params, example }) => ({ name, description, params, example }));
writeFileSync(new URL("../test/fixtures/catalog.json", import.meta.url), JSON.stringify(catalog, null, 1) + "\n");
console.log(`${catalog.length} actions`);
