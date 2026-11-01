<?php

use App\Http\Controllers\GuestbookController;
use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class);
Route::get('/', [GuestbookController::class, 'index']);
Route::post('/', [GuestbookController::class, 'store']);
