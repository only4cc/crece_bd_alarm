set TEXT="%1%"
set TOKEN='https://hooks.slack.com/services/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'

curl -X POST --data-urlencode 'payload={"channel": "#aprendizaje-de-slack", "username": "tychonew", "text": "Texto del Post ...", "icon_emoji": ":ghost:"}' %TOKEN%