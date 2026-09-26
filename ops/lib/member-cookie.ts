// The website member session: the backend access token from a phone code or
// phone + PIN sign-in, kept in an httpOnly cookie the browser's scripts never see.
export const MEMBER_COOKIE = 'omoterra_member';
export const MEMBER_MAX_AGE = 60 * 60 * 24 * 30;
