<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Guestbook</title>
</head>
<body>
    <h1>Guestbook</h1>

    @if (session('status'))
        <p>{{ session('status') }}</p>
    @endif

    <form method="POST" action="/">
        @csrf
        <input type="text" name="name" placeholder="Your name" required>
        <textarea name="body" placeholder="Your message" required></textarea>
        <button type="submit">Sign</button>
    </form>

    @foreach ($messages as $message)
        <div>
            <strong>{{ $message->name }}</strong>
            <p>{{ $message->body }}</p>
        </div>
    @endforeach
</body>
</html>
