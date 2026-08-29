<?php

namespace Tests\Feature;

use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Foundation\Auth\User as AuthenticatableUser;
use Laravel\Sanctum\HasApiTokens;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SanctumConfigurationTest extends TestCase
{
    public function test_api_route_requires_a_sanctum_token(): void
    {
        $this->getJson('/api/sprint-0/sanctum-check')
            ->assertUnauthorized();
    }

    public function test_sanctum_allows_an_authenticated_request(): void
    {
        Sanctum::actingAs(new SprintZeroUser());

        $this->getJson('/api/sprint-0/sanctum-check')
            ->assertOk()
            ->assertJson(['status' => 'authenticated']);
    }
}

class SprintZeroUser extends AuthenticatableUser implements Authenticatable
{
    use HasApiTokens;
}
