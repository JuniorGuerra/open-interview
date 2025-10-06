from flask import Flask, render_template_string, jsonify
from redis import Redis
import os

app = Flask(__name__)
redis = Redis(host=os.getenv('REDIS_HOST', 'localhost'), port=6379)

# Template HTML con Bootstrap
html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Visitor Counter App</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #f8f9fa;
        }
        .counter-card {
            margin-top: 100px;
            text-align: center;
            background: white;
            border-radius: 15px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            padding: 2rem;
        }
        .counter {
            font-size: 4rem;
            font-weight: bold;
            color: #0d6efd;
            margin: 1rem 0;
        }
        .subtitle {
            color: #6c757d;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-6">
                <div class="counter-card">
                    <h1>Welcome!</h1>
                    <p class="subtitle">You are visitor number:</p>
                    <div class="counter">{{ count }}</div>
                    <p class="text-muted">Powered by Flask + Redis</p>
                </div>
            </div>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"""

@app.route('/')
def hello():
    count = redis.incr('visits')
    return render_template_string(html_template, count=count)

@app.route('/api/visits')
def visits_api():
    count = redis.get('visits')
    return jsonify({
        'visits': int(count) if count else 0
    })

@app.route('/health')
def health():
    try:
        redis.ping()
        return jsonify({'status': 'healthy'})
    except:
        return jsonify({'status': 'unhealthy'}), 500

@app.route('/reset', methods=['POST'])
def reset():
    redis.set('visits', 0)
    return jsonify({'message': 'Counter reset to 0'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)