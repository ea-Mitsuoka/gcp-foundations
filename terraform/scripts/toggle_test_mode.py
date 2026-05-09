import os, random, string, re

path = "terraform/common.tfvars"
if os.path.exists(path):
    with open(path, "r") as f: c = f.read()
    m = re.search(r'project_id_prefix\s*=\s*"([^"]+)"', c)
    if m:
        curr = m.group(1)
        # すでに4桁のランダムサフィックス(-a1b2など)がついているか判定
        if re.search(r"-[0-9a-f]{2}$", curr):
            new = re.sub(r"-[0-9a-f]{2}$", "", curr)
            print(f"✅ テストモード【OFF】: プレフィックスを '{new}' (本番固定名) に戻しました。")
            if os.path.exists(".test_mode_env"): os.remove(".test_mode_env")
        else:
            s = "".join(random.choices("abcdef0123456789", k=2))
            new = f"{curr}-{s}"
            print(f"🧪 テストモード【ON】: プレフィックスを '{new}' に変更しました。")
            with open(".test_mode_env", "w") as env_f:
                env_f.write("export SKIP_MANAGEMENT_PROJECTS=true\n")
        
        with open(path, "w") as f:
            f.write(c.replace(f'"{curr}"', f'"{new}"'))
    else:
        print("❌ project_id_prefix が見つかりません。")
else:
    print("❌ common.tfvars が見つかりません。")
