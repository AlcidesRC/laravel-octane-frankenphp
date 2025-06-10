<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::post('/post', function (Illuminate\Http\Request $request) {
    return response()->json([
        'param1' => $request->get('param1'),
        'param2' => $request->get('param2'),
    ]);
});
