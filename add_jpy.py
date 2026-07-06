import os

target_dir = 'E:/dev/hesap_takip/test'
jpy_line = "  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),\n"

for root, _, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            if "Currency(code: 'GBP'" in content and "Currency(code: 'JPY'" not in content:
                # Insert JPY after GBP
                new_content = content.replace("Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),",
                                              "Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),\n" + jpy_line)
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f'Added JPY to {path}')
