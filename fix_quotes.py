import os

target_dir = 'E:/dev/hesap_takip/test'

for root, _, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            if "\\'TRY\\'" in content or "\\'USD\\'" in content or "\\'EUR\\'" in content or "\\'GBP\\'" in content or "\\'₺\\'" in content or "\\'$\\'" in content or "\\'€\\'" in content or "\\'£\\'" in content:
                new_content = content.replace("\\'", "'")
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f'Fixed {path}')
