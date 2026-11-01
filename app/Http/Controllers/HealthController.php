<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function __invoke()
    {
        try {
            DB::select('SELECT 1');

            return response("OK", 200->header('Content-Type', 'text/plain');
        } catch (\Throwable $e) {
            return response('DATABASE UNAVAILABLE', 503)->header('Content-Type', 'text/plain');
        }
    }
}
