from flask import Flask, request, render_template
from transformers import GPT2LMHeadModel, GPT2Tokenizer

app = Flask(__name__)

# Load pre-trained model and tokenizer
model = GPT2LMHeadModel.from_pretrained("gpt2")
tokenizer = GPT2Tokenizer.from_pretrained("gpt2")

@app.route('/', methods=['GET', 'POST'])
def home():
    if request.method == 'POST':
        # Get the user input from the form
        user_input = request.form.get('user_input')

        # Encode input and generate response
        inputs = tokenizer.encode(user_input, return_tensors="pt")
        outputs = model.generate(inputs, max_length=150, num_return_sequences=1, no_repeat_ngram_size=2)

        # Decode the output and remove the original input
        generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
        generated_text = generated_text[len(user_input):]

        return render_template('home.html', generated_text=generated_text)

    return render_template('home.html')

if __name__ == '__main__':
    app.run(debug=True)
