import os, random, string, re

path = "terraform/common.tfvars"
env_file = ".test_mode_env"

if os.path.exists(path):
    with open(path, "r") as f:
        c = f.read()
    
    m = re.search(r'project_id_prefix\s*=\s*"([^"]+)"', c)
    if m:
        curr = m.group(1)
        
        # 判定基準を「状態ファイル(.test_mode_env)が存在するか」に変更
        if os.path.exists(env_file):
            # --- テストモード OFF への切り替え ---
            with open(env_file, "r") as f:
                env_content = f.read()
            
            # 付与したサフィックスを正確に取得して取り除く（誤爆防止）
            suffix_match = re.search(r'TEST_SUFFIX=([^ \n]+)', env_content)
            if suffix_match:
                suffix = suffix_match.group(1)
                # 現在のプレフィックスが記録したサフィックスで終わっている場合のみ削る
                if curr.endswith(suffix):
                    new = curr[:-len(suffix)]
                else:
                    new = curr # 手動で変更された等、想定外の場合はそのまま
            else:
                # 互換性フォールバック (古いenvファイルが残っていた場合)
                new = re.sub(r"-[0-9a-f]{2}$", "", curr)
                
            print(f"✅ テストモード【OFF】: プレフィックスを '{new}' (本番固定名) に戻しました。")
            os.remove(env_file)
            
            with open(path, "w") as f:
                f.write(c.replace(f'"{curr}"', f'"{new}"'))
                
        else:
            # --- テストモード ON への切り替え ---
            s = "".join(random.choices("abcdef0123456789", k=2))
            suffix = f"-{s}"
            new = f"{curr}{suffix}"
            
            print(f"🧪 テストモード【ON】: プレフィックスを '{new}' に変更しました。")
            
            # テストモードの状態と、付与したサフィックスの両方をファイルに記録する
            with open(env_file, "w") as env_f:
                env_f.write("export SKIP_MANAGEMENT_PROJECTS=true\n")
                env_f.write(f"export TEST_SUFFIX={suffix}\n")
        
            with open(path, "w") as f:
                f.write(c.replace(f'"{curr}"', f'"{new}"'))
    else:
        print("❌ project_id_prefix が見つかりません。")
else:
    print("❌ common.tfvars が見つかりません。")
