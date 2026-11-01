<?php

namespace App\Http\Controllers;

use App\Models\Message;
use Illuminate\Http\Request;

class GuestbookController extends Controller
{
    public function index()
    {
        $messages = Message::latest()->get();

        return view('guestbook', compact('messages'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
            'author' => 'nullable|string|max:100',
            'body' => 'required|string|max:1000',
        ]);

        Message::create($data);

        return redirect('/')->with('status', 'Message saved!');
    }
}
