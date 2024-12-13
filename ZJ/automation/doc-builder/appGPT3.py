from flask import Flask, request, render_template
import openai
import os

api_key = os.getenv('apikey')
openai.api_key = api_key

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def home():
    if request.method == 'POST':
        # Get the user inputs from the form
        title = request.form.get('title')
        introduction = request.form.get('introduction')
        conclusion = request.form.get('conclusion')

        # Use the OpenAI API to generate the body of the document
        prompt = f"{introduction}\n\n{title}:"
        response = openai.Completion.create(engine="text-ada-001", prompt=prompt, max_tokens=100)

        # Get the generated text
        body = response.choices[0].text.strip()

        # Combine the user inputs and generated text to form the document
        document = f"{title}\n\n{introduction}\n\n{body}\n\n{conclusion}"

        return render_template('home.html', document=document)

    return render_template('home.html')

if __name__ == '__main__':
    app.run(debug=True)
