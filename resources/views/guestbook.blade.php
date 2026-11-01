<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Guestbook</title>
</head>
<body>
    <h1>Guestbook (deployed by Git)</h1>

    @if (session('status'))
        <p>{{ session('status') }}</p>
    @endif

    <form method="POST" action="/">
        @csrf
        <input type="text" name="name" placeholder="Your name" required>
        <input type="text" name="author" placeholder="Author (optional)">
        <textarea name="body" placeholder="Your message" required></textarea>
        <button type="submit">Sign</button>
    </form>

    @foreach ($messages as $message)
        <div>
            <strong>{{ $message->name }}</strong> <em>{{ $message->author }}</em>
            <p>{{ $message->body }}</p>
        </div>
    @endforeach
</body>
</html>
