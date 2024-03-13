# mod_cookie_auth

`mod_cookie_auth` is a Lua hook script implemented for the Apache2 HTTP server. Its primary functionality involves storing authentication results within a cookie, effectively reducing the number of authentication prompts whenever a browser restarts. This feature proves extremely beneficial for mobile web applications that depend on HTTP authentication techniques, given that the 'Authorization' header might get lost when inactive tabs are put into sleep mode by mobile browsers.

# Quick Start

## Installation

To clone the repository and install mod_cookie_auth, run:

```sh
git clone https://github.com/vivimice/mod_cookie_auth.git
cd mod_cookie_auth
sudo ./install.sh
```

## Configure

You may need to generate a digest salt. The following command can be used to create one:

```sh
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
```

After generating a salt, proceed to modifying your Apache2 configuration file. Append the following lines in the configuration file:

```apache
LuaHookAccessChecker /usr/local/lib/mod_cookie_auth/mod_cookie_auth.lua check late
LuaHookAuthChecker   /usr/local/lib/mod_cookie_auth/mod_cookie_auth.lua store early
SetEnvIf Host .*     MOD_COOKIE_AUTH_SALT=<put_your_random_generated_salt_here>
```

Replacing `<put_your_random_generated_salt_here>` with the output of the digest salt command.

## Activation

Finally, to enable necessary modules, check the updated configuration, and reload your Apache2 instance for the changes to take effect, use the following commands:

```sh
sudo a2enmod lua setenvif
sudo apache2ctl configtest && sudo apache2ctl graceful
```

# How it works

Upon successful initial authentication by standard authentication modules (modauthbasic or modauthdigeset), the `mod_cookie_auth` hook generates a cookie. This cookie contains the authenticated user details, expiration time, and a checksum.

In instances where the browser is restored from sleep, the 'Authorization' header may be cleared. During such instances, `mod_cookie_auth` is capable of restoring the user's authentication state using the persisted cookies.

# Configuration

The `mod_cookie_auth` can be customized using the `Set-EnvIf` directive (Please note that `Set-Env` is not suited for this purpose, more information can be found [here](https://httpd.apache.org/docs/2.4/mod/mod_env.html)). The template for the configuration appears as follows:

```apache
SetEnvIf Host .* <CONFIG_NAME>=<CONFIG_VALUE>
```

The aforementioned configuration directive can be implemented in several contexts such as the server configuration, virtual host, directory, or .htaccess.

|Config Name|Type|Required|Comment|
|-|-|-|-|
|MOD_COOKIE_AUTH_SALT|string|yes|The salt is employed in generating the checksum portion of the cookie value. <br/>**NOTE**:  It's crucial to generate intricate values in this section to guarantee sufficient security against brute force attacks.|
|MOD_COOKIE_AUTH_KEY|string|no|The name of the cookie. <br />Default value: `mcasec`|
|MOD_COOKIE_AUTH_TTL|int|no|The maximum expiry time (in seconds) of the authentication period since the last successful access. <br />Default value: `86400`|
|MOD_COOKIE_AUTH_PATH|string|no|The path section of the outgoing cookie. <br />Default value: `/`|
|MOD_COOKIE_AUTH_DISABLE_SECURE_COOKIE|string|no|Configure the parameter as `this_is_unsafe` to omit the `secure` attribute from the cookie.<br />**IMPORTANT**: Exposing cookies in unencrypted traffic is a security risk. For more details, refer to the [Security](#Security) section of the documentation.|

# Security Consideration

## Cookie hijacking

The `mod_cookie_auth` module, which is based on cookies, is susceptible to cookie hijacking. To counteract this vulnerability, `mod_cookie_auth` implements a widely-used protection method against cookie hijacking.

By default, the `mod_cookie_auth` module enables both `http_only` and `secure` attributes. These attributes instruct the browser to hide the cookie value from scripts and unencrypted traffic. The `secure` attribute can be disabled by setting the `MOD_COOKIE_AUTH_DISABLE_SECURE_COOKIE` configuration to `this_is_unsafe`. This setting should ONLY be utilized in scenarios where SSL is not applicable.

## Digest Salting

The `mod_cookie_auth` module utilizes salted MD5 to mitigate the risk of cookie value forgery. For enhanced resistance against dictionary attacks, it is advisable to set a private, highly random value for the `MOD_COOKIE_AUTH_SALT` configuration.
