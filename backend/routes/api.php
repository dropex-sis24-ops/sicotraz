<?php

app('router')->middleware('auth:sanctum')->get('/sprint-0/sanctum-check', function () {
    return response()->json(['status' => 'authenticated']);
});
