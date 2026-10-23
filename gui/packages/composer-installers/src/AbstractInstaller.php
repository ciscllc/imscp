<?php

namespace iMSCP\Composer;

use Composer\Composer;
use Composer\IO\IOInterface;
use Composer\Package\PackageInterface;

abstract class AbstractInstaller
{
    protected $locations = [];
    protected $composer;
    protected $package;
    protected $io;

    public function __construct(
        PackageInterface $package = null,
        Composer $composer = null,
        IOInterface $io = null
    ) {
        $this->composer = $composer;
        $this->package = $package;
        $this->io = $io;
    }

    public function getInstallPath(PackageInterface $package, $installerType = ''): string
    {
        $type = $this->package->getType();
        $prettyName = $this->package->getPrettyName();
        if (strpos($prettyName, '/') !== false) {
            list($vendor, $name) = explode('/', $prettyName);
        } else {
            $vendor = '';
            $name = $prettyName;
        }

        $availableVars = $this->inflectPackageVars(compact('name', 'vendor', 'type'));
        $extra = $package->getExtra();
        if (!empty($extra['installer-name'])) {
            $availableVars['name'] = $extra['installer-name'];
        }

        if ($this->composer->getPackage()) {
            $extra = $this->composer->getPackage()->getExtra();
            if (!empty($extra['installer-paths'])) {
                $customPath = $this->mapCustomInstallPaths($extra['installer-paths'], $prettyName, $type, $vendor);
                if ($customPath !== false) {
                    return $this->templatePath($customPath, $availableVars);
                }
            }
        }

        $packageType = substr($type, strlen($installerType) + 1);
        $locations = $this->getLocations();
        if (!isset($locations[$packageType])) {
            throw new \InvalidArgumentException(sprintf('Package type "%s" is not supported', $type));
        }

        return $this->templatePath($locations[$packageType], $availableVars);
    }

    public function inflectPackageVars(array $vars): array
    {
        return $vars;
    }

    /**
     * @return string|false
     */
    protected function mapCustomInstallPaths(array $paths, $name, $type, $vendor = null)
    {
        foreach ($paths as $path => $names) {
            if (in_array($name, $names, true) || in_array('type:' . $type, $names, true) || in_array('vendor:' . $vendor, $names, true)) {
                return $path;
            }
        }

        return false;
    }

    protected function templatePath($path, array $vars = []): string
    {
        if (strpos($path, '{') !== false) {
            extract($vars);
            preg_match_all('@\{\$([A-Za-z0-9_]*)\}@i', $path, $matches);
            foreach ($matches[1] as $var) {
                $path = str_replace('{$' . $var . '}', $$var, $path);
            }
        }

        return $path;
    }

    public function getLocations(): array
    {
        return $this->locations;
    }
}
