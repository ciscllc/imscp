<?php

namespace iMSCP\Composer;

class RoundcubeInstaller extends AbstractInstaller
{
    protected $locations = [
        'plugin' => 'plugins/{$name}/',
    ];

    public function inflectPackageVars(array $vars): array
    {
        $vars['name'] = strtolower(str_replace('-', '_', $vars['name']));
        return $vars;
    }
}
